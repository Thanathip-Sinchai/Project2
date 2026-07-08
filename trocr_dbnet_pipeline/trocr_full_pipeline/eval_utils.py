import evaluate as hf_evaluate
import torch

cer_metric = hf_evaluate.load("cer")

def evaluate_model(model, processor, dataloader, device):
    preds, refs = [], []

    model.eval()
    with torch.no_grad():
        for batch in dataloader:
            pixel_values = batch["pixel_values"].to(device)
            labels = batch["labels"]

            outputs = model.generate(pixel_values)

            preds.extend(
                processor.batch_decode(outputs, skip_special_tokens=True)
            )
            refs.extend(
                processor.batch_decode(labels, skip_special_tokens=True)
            )

    cer = cer_metric.compute(predictions=preds, references=refs)

    total, correct = 0, 0
    for p, r in zip(preds, refs):
        total += len(r)
        correct += sum(a == b for a, b in zip(p, r))

    acc = correct / total if total > 0 else 0

    return cer, acc