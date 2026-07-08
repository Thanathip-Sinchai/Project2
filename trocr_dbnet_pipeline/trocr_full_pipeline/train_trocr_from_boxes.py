import os
import json
import csv
from PIL import Image

import torch
from torch.utils.data import Dataset, random_split

from transformers import (
    TrOCRProcessor,
    VisionEncoderDecoderModel,
    Seq2SeqTrainer,
    Seq2SeqTrainingArguments,
)

import evaluate


# ===================== Dataset =====================
class BoxOCRDataset(Dataset):
    def __init__(
        self,
        annotations_path,
        image_root,
        processor,
        max_target_length=64,
        field_filter=None,
        min_text_len=1,
    ):
        self.image_root = image_root
        self.processor = processor
        self.max_target_length = max_target_length

        with open(annotations_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.samples = []
        for rel_path, boxes in data.items():
            for box in boxes:
                text = (box.get("transcription") or "").strip()
                field = box.get("field", None)

                if field_filter and field != field_filter:
                    continue
                if len(text) < min_text_len:
                    continue

                self.samples.append({
                    "image_path": rel_path,
                    "points": box["points"],
                    "text": text,
                })

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        item = self.samples[idx]
        img_path = os.path.join(self.image_root, item["image_path"])
        image = Image.open(img_path).convert("RGB")

        pts = item["points"]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        xmin, xmax = min(xs), max(xs)
        ymin, ymax = min(ys), max(ys)

        crop = image.crop((xmin, ymin, xmax, ymax))
        text = item["text"]

        encoding = self.processor(
            images=crop,
            text=text,
            return_tensors="pt",
            padding="max_length",
            max_length=self.max_target_length,
            truncation=True,
        )

        encoding = {k: v.squeeze(0) for k, v in encoding.items()}
        encoding["labels"] = encoding["labels"].clone()
        return encoding


def collate_fn(batch):
    return {k: torch.stack([b[k] for b in batch]) for k in batch[0]}


# ===================== Main =====================
def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--annotations_path", required=True)
    parser.add_argument("--image_root", required=True)
    parser.add_argument("--output_dir", default="trocr_model")
    parser.add_argument("--pretrained_model", default="openthaigpt/thai-trocr")
    parser.add_argument("--num_train_epochs", type=int, default=10)
    parser.add_argument("--batch_size", type=int, default=4)
    parser.add_argument("--max_target_length", type=int, default=64)
    parser.add_argument("--field_filter", default=None)
    parser.add_argument("--min_text_len", type=int, default=1)
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    processor = TrOCRProcessor.from_pretrained(args.pretrained_model)
    model = VisionEncoderDecoderModel.from_pretrained(args.pretrained_model)
    model.to(device)

    dataset = BoxOCRDataset(
        args.annotations_path,
        args.image_root,
        processor,
        max_target_length=args.max_target_length,
        field_filter=args.field_filter,
        min_text_len=args.min_text_len,
    )

    if len(dataset) == 0:
        raise ValueError("Dataset is empty")

    n_train = int(len(dataset) * 0.9)
    n_val = len(dataset) - n_train
    train_dataset, eval_dataset = random_split(dataset, [n_train, n_val])

    cer_metric = evaluate.load("cer")

    def compute_metrics(eval_pred):
        preds, labels = eval_pred
        labels[labels == -100] = processor.tokenizer.pad_token_id

        pred_str = processor.batch_decode(preds, skip_special_tokens=True)
        label_str = processor.batch_decode(labels, skip_special_tokens=True)

        cer = cer_metric.compute(
            predictions=pred_str,
            references=label_str
        )
        return {"cer": cer}

    training_args = Seq2SeqTrainingArguments(
        output_dir=args.output_dir,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.batch_size,
        num_train_epochs=args.num_train_epochs,
        evaluation_strategy="epoch",
        save_strategy="epoch",
        logging_strategy="epoch",
        predict_with_generate=True,
        remove_unused_columns=False,
        fp16=torch.cuda.is_available(),
        report_to="none",
    )

    trainer = Seq2SeqTrainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        data_collator=collate_fn,
        tokenizer=processor.tokenizer,
        compute_metrics=compute_metrics,
    )

    trainer.train()

    # ===================== Save training log =====================
    log_path = os.path.join(args.output_dir, "training_log.csv")
    with open(log_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["epoch", "train_loss", "eval_loss", "eval_cer"])

        for log in trainer.state.log_history:
            if "epoch" in log:
                writer.writerow([
                    log.get("epoch"),
                    log.get("loss"),
                    log.get("eval_loss"),
                    log.get("eval_cer"),
                ])

    trainer.save_model(args.output_dir)
    processor.save_pretrained(args.output_dir)

    print("✅ Training finished")
    print(f"📄 Log saved to: {log_path}")


if __name__ == "__main__":
    main()