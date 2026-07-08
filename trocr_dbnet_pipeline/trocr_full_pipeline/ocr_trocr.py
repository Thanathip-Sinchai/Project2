# ocr_trocr.py
from transformers import TrOCRProcessor, VisionEncoderDecoderModel
from PIL import Image
import torch

def load_trocr(model_path="openthaigpt/thai-trocr"):
    processor = TrOCRProcessor.from_pretrained(model_path)
    model = VisionEncoderDecoderModel.from_pretrained(model_path)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model.to(device)
    model.eval()
    return processor, model, device

def ocr_crops(crops, processor, model, device):
    results = []
    for crop in crops:
        img = Image.open(crop["crop_path"]).convert("RGB")
        inputs = processor(images=img, return_tensors="pt")
        inputs = {k: v.to(device) for k, v in inputs.items()}

        with torch.no_grad():
            pred_ids = model.generate(
                **inputs,
                max_length=64,
                num_beams=4,
                early_stopping=True
            )

        text = processor.batch_decode(pred_ids, skip_special_tokens=True)[0]
        text = (text or "").strip()

        results.append({
            "text": text,
            "bbox": crop["bbox"],
            "y_center": crop["y_center"],
            "crop_path": crop["crop_path"]
        })
    return results
