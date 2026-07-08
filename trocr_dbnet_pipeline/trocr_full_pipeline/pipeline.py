import argparse
import os
import json
import cv2
import numpy as np
from typing import Dict, Any

from detect_text import detect_and_crop
from ocr_trocr import load_trocr, ocr_crops
from extract_fields import extract_fields

# -------------------------
# Global cache (โหลดโมเดลครั้งเดียว)
# -------------------------
_GLOBAL = {
    "model_name": None,
    "processor": None,
    "trocr_model": None,
    "device": None,
    "use_gpu": False,
}


def init_pipeline(model: str = "openthaigpt/thai-trocr", use_gpu: bool = False):
    global _GLOBAL

    if (
        _GLOBAL["processor"] is not None
        and _GLOBAL["trocr_model"] is not None
        and _GLOBAL["model_name"] == model
        and _GLOBAL["use_gpu"] == use_gpu
    ):
        return _GLOBAL["processor"], _GLOBAL["trocr_model"], _GLOBAL["device"]

    processor, trocr_model, device = load_trocr(model_path=model)

    _GLOBAL["model_name"] = model
    _GLOBAL["processor"] = processor
    _GLOBAL["trocr_model"] = trocr_model
    _GLOBAL["device"] = device
    _GLOBAL["use_gpu"] = use_gpu

    return processor, trocr_model, device


def save_visual_output(image_path: str, crops, save_path: str):
    """
    สร้าง sample_output.png (กรอบ DBNet + ข้อความ OCR)
    """
    img = cv2.imread(image_path)
    if img is None:
        print("⚠️ ไม่สามารถเปิดภาพเพื่อวาดผลลัพธ์ได้")
        return

    for c in crops:
        box = c.get("box")
        text = c.get("text", "")

        if not box:
            continue

        pts = np.array(box, dtype=np.int32)

        # วาดกรอบ
        cv2.polylines(img, [pts], True, (0, 255, 0), 2)

        # วาดข้อความ
        x, y = pts[0]
        cv2.putText(
            img,
            text,
            (x, max(y - 5, 15)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (0, 0, 255),
            1,
            cv2.LINE_AA
        )

    os.makedirs(os.path.dirname(save_path), exist_ok=True)
    cv2.imwrite(save_path, img)
    print(f"🖼️ Saved visual output → {save_path}")


def _dump_debug_lines(crop_results, out_path: str):
    """
    บันทึกข้อมูล OCR lines ดิบ เพื่อเอาไป debug/ส่งต่อได้
    """
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(crop_results, f, ensure_ascii=False, indent=2)
    print(f"🐞 Saved debug OCR lines → {out_path}")


def _print_ocr_lines(crop_results, title: str = "OCR LINES (RAW)"):
    """
    พิมพ์ OCR lines ดิบทั้งหมด เพื่อดูว่ามีวันที่/size อยู่ในรูปแบบไหน
    """
    print(f"\n===== {title} =====")
    for i, it in enumerate(crop_results):
        txt = it.get("text", "")
        bbox = it.get("bbox", None)
        y_center = it.get("y_center", None)
        print(f"{i:02d} text={repr(txt)}  bbox={bbox}  y_center={y_center}")
    print("===== END =====\n")


def run_pipeline(
    image_path: str,
    model: str,
    out_path: str,
    use_gpu: bool = False,
    tmp_crop_dir: str = "tmp_crops",
) -> Dict[str, Any]:
    """
    CLI pipeline:
    detect → crop → OCR → extract_fields → save JSON + sample_output.png
    """

    # 1) detect + crop
    crops = detect_and_crop(
        image_path,
        out_dir=tmp_crop_dir,
        save_annotated=True,
        use_gpu=use_gpu
    )

    # 2) load TrOCR (cache)
    processor, trocr_model, device = init_pipeline(model=model, use_gpu=use_gpu)

    # 3) OCR
    crop_results = ocr_crops(crops, processor, trocr_model, device)

    # ผูก text กลับเข้า crops (ไม่กระทบ logic เดิม)
    for c, r in zip(crops, crop_results):
        c["text"] = r.get("text", "")

    # ✅ DEBUG: พิมพ์ OCR lines ดิบ + เซฟไฟล์ debug
    _print_ocr_lines(crop_results, title="OCR LINES (RAW) - CLI")
    _dump_debug_lines(crop_results, out_path="outputs/debug_ocr_lines.json")

    # 4) Extract fields
    fields = extract_fields(crop_results)

    # ✅ DEBUG: พิมพ์ fields หลัง extract
    print("===== EXTRACTED FIELDS (CLI) =====")
    print(json.dumps(fields, ensure_ascii=False, indent=2))
    print("===== END EXTRACTED FIELDS =====\n")

    # 5) Save JSON (fields)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(fields, f, ensure_ascii=False, indent=2)

    print(f"✅ DONE → {out_path}")
    print(fields)

    # 6) Save sample_output.png
    save_visual_output(
        image_path=image_path,
        crops=crops,
        save_path="results/sample_output.png"
    )

    return fields

def infer_ocr(
    image_path: str,
    model: str = "openthaigpt/thai-trocr",
    use_gpu: bool = False,
    tmp_crop_dir: str = "tmp_crops",
) -> Dict[str, Any]:
    crops = detect_and_crop(
        image_path,
        out_dir=tmp_crop_dir,
        save_annotated=False,
        use_gpu=use_gpu
    )

    processor, trocr_model, device = init_pipeline(model=model, use_gpu=use_gpu)

    crop_results = ocr_crops(crops, processor, trocr_model, device)

    # (optional) save debug lines ไว้ดู
    os.makedirs("outputs", exist_ok=True)
    with open("outputs/debug_ocr_lines_api.json", "w", encoding="utf-8") as f:
        json.dump(crop_results, f, ensure_ascii=False, indent=2)

    fields = extract_fields(crop_results)

    return {
        "ok": True,
        "model": model,
        "fields": fields,
        "lines": crop_results,   # ✅ สำคัญมาก
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--image_path", required=True)
    parser.add_argument("--out", default="outputs/result.json")
    parser.add_argument("--model", default="openthaigpt/thai-trocr")
    parser.add_argument("--use_gpu", action="store_true")
    args = parser.parse_args()

    run_pipeline(
        args.image_path,
        args.model,
        args.out,
        use_gpu=args.use_gpu
    )
