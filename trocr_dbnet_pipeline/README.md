DBNet (via PaddleOCR) + TrOCR pipeline for structured label extraction (Thai-ready)
=================================================================================

This project runs a pipeline:
1) Text Detection using DBNet (via PaddleOCR)
2) OCR per-crop using TrOCR (HuggingFace)
3) Rule-based Field Extraction to JSON (product_name, price, mfg_date, exp_date, barcode, size/quantity)

Important notes:
- PaddlePaddle installation depends on your platform and GPU. See https://www.paddlepaddle.org.cn/install/quick for proper wheel selection.
- TrOCR will use HuggingFace transformers. For training/fine-tuning use the training scripts from your trocr project.
- This project provides inference pipeline code. You may need to install suitable paddlepaddle package (cpu or gpu) before running.

Quick start:
1. Create and activate venv
   Windows Powershell:
     python -m venv .venv
     .\.venv\Scripts\Activate.ps1
2. Install dependencies (adjust paddlepaddle command according to your CUDA version)
   pip install -r requirements.txt
   # If you have GPU and CUDA 12.1 for example, choose matching paddlepaddle wheel, e.g.:
   # pip install paddlepaddle-gpu==2.5.2.post121 -f https://www.paddlepaddle.org.cn/whl/windows/mkl/avx/stable.html
3. Place images in `data/images/`
4. Run pipeline:
   python pipeline.py --image_path data/images/example.jpg --output_json out.json

Files in this repo:
- detect_text.py   : uses PaddleOCR DB detector to extract text boxes (and crops)
- ocr_trocr.py     : runs TrOCR model on crops (GPU if available)
- extract_fields.py: rule-based extractor to map OCR results to fields
- pipeline.py      : run detection -> OCR -> extraction, and save JSON output
- example (data/)  : create your data/images folder and put images to test
