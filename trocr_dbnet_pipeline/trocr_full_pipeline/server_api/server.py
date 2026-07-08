from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import tempfile, os, sys, json, importlib

# ==========================================================
# ให้ server_api มองเห็นไฟล์ในโฟลเดอร์ราก (trocr_full_pipeline)
# server_api/server.py
# ../pipeline.py, ../extract_fields.py, ../trocr_model/
# ==========================================================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # โฟลเดอร์ราก
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

# ✅ import จากโฟลเดอร์ราก
import pipeline as pipeline_mod
import extract_fields as extract_fields_mod
from pipeline import infer_ocr, init_pipeline

# ==========================================================
# ✅ FIX สำคัญ: ใช้โมเดลเดียวกับ CLI
# CLI ของคุณใช้: --model trocr_model --use_gpu
# ==========================================================
MODEL_NAME = os.path.join(BASE_DIR, "trocr_model")  # ชี้ path เต็ม (กัน cwd อยู่ server_api)
USE_GPU = True  # ให้เหมือน CLI (ถ้าเครื่องรองรับ CUDA)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ตอนพัฒนาเปิดก่อน
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup_event():
    # ✅ reload กันไฟล์เก่าค้าง (ช่วยตอน dev)
    importlib.reload(extract_fields_mod)
    importlib.reload(pipeline_mod)

    # ✅ preload โมเดล
    init_pipeline(model=MODEL_NAME, use_gpu=USE_GPU)

    print("✅ Model preloaded!")
    print("🔎 BASE_DIR:", BASE_DIR)
    print("🔎 python:", sys.executable)
    print("🔎 cwd:", os.getcwd())
    print("🔎 pipeline file:", pipeline_mod.__file__)
    print("🔎 extract_fields file:", extract_fields_mod.__file__)
    print("🔎 MODEL_NAME:", MODEL_NAME)
    print("🔎 USE_GPU:", USE_GPU)
    print("🔎 model_exists:", os.path.exists(MODEL_NAME))

@app.get("/ping")
def ping():
    return {"ok": True, "message": "OCR API is running"}

@app.get("/debug_imports")
def debug_imports():
    return {
        "BASE_DIR": BASE_DIR,
        "python_executable": sys.executable,
        "cwd": os.getcwd(),
        "pipeline_file": getattr(pipeline_mod, "__file__", None),
        "extract_fields_file": getattr(extract_fields_mod, "__file__", None),
        "MODEL_NAME": MODEL_NAME,
        "USE_GPU": USE_GPU,
        "model_exists": os.path.exists(MODEL_NAME),
        "sys_path_head": sys.path[:6],
    }

@app.post("/ocr")
async def ocr(image: UploadFile = File(...)):
    suffix = os.path.splitext(image.filename)[-1].lower() or ".jpg"

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await image.read())
        tmp_path = tmp.name

    try:
        # ✅ reload กันแก้ไฟล์แล้วไม่อัปเดต
        importlib.reload(extract_fields_mod)
        importlib.reload(pipeline_mod)

        result = infer_ocr(tmp_path, model=MODEL_NAME, use_gpu=USE_GPU)

        # ✅ log debug ให้เห็น fields + บรรทัด OCR
        print("\n========== /ocr DEBUG ==========")
        print("file:", image.filename, "->", tmp_path)
        print("MODEL_NAME:", MODEL_NAME, "USE_GPU:", USE_GPU)
        print("fields:", json.dumps(result.get("fields", {}), ensure_ascii=False))
        lines = result.get("lines") or []
        print("lines_count:", len(lines))
        if len(lines) > 0:
            for i, it in enumerate(lines[:20]):
                print(i, repr(it.get("text", "")))
        print("========== END DEBUG ==========\n")

        return result
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

# ==========================================================
# ✅ Run server ให้มือถือจริงเข้าถึงได้
# - bind 0.0.0.0
# - ใช้ PORT จาก env ได้ (default 8000)
# ==========================================================
if __name__ == "__main__":
    import uvicorn

    host = os.environ.get("HOST", "0.0.0.0")
    
    port = int(os.environ.get("PORT", "8000"))

    print(f"🚀 OCR API running on http://{host}:{port}")
    print("📱 For real device use your PC IP, e.g. http://10.50.11.199:8000")

    uvicorn.run("server:app", host=host, port=port, reload=False)
