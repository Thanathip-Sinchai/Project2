import argparse
import subprocess
import sys
import os
import json

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--model_path",
        default="trocr_model",
        help="Path to trained TrOCR model"
    )
    args = parser.parse_args()

    base_dir = os.path.dirname(__file__)
    image_path = os.path.join(base_dir, "Data", "images", "img_168.jpg")
    out_path = os.path.join(base_dir, "outputs", "test_result.json")

    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    cmd = [
        sys.executable, "pipeline.py",
        "--image_path", image_path,
        "--out", out_path,
        "--model", args.model_path,
        "--use_gpu"
    ]

    subprocess.check_call(cmd)

    with open(out_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    print("✅ OCR result:")
    print(json.dumps(data, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()