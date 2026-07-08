import re

# -----------------------------
# Normalization helpers
# -----------------------------
THAI_DIGITS = str.maketrans("๐๑๒๓๔๕๖๗๘๙", "0123456789")

# ตัวที่ OCR ชอบอ่านผิดใน "บริบทตัวเลข"
NUM_CONFUSIONS = str.maketrans({
    "O": "0", "o": "0", "๐": "0",
    "I": "1", "l": "1", "|": "1", "！": "1",
    "S": "5", "s": "5",
})

def norm(t: str) -> str:
    t = (t or "").strip()
    t = t.translate(THAI_DIGITS)
    t = t.replace("：", ":").replace("–", "-").replace("—", "-")
    t = re.sub(r"\s+", " ", t)
    return t.strip()

def norm_numeric_context(t: str) -> str:
    """
    แก้เฉพาะตัวอักษรที่มักเพี้ยนเป็นตัวเลข
    ใช้กับข้อความที่ 'น่าจะเป็น' วันที่/เลข/ขนาด
    """
    t = norm(t)
    return t.translate(NUM_CONFUSIONS)

def contains_any_digit(t: str) -> bool:
    return bool(re.search(r"\d", t or ""))

# -----------------------------
# Patterns
# -----------------------------
BARCODE_RE = re.compile(r"^\d{7,13}$")  # 7-13 digits

# หน่วยขนาด/จำนวน (เพิ่มตามใช้งานจริงได้)
# ใส่รูปแบบเพี้ยนของ "ชิ้น" ด้วย
UNIT_VARIANTS = [
    "ชิ้น", "ช็น", "ซิ้น", "ซิ้น", "ชน", "ชิน", "ชํ้น", "ช้้น", "ช่ิน", "ชิ่้น",
    "แท่ง", "ซอง", "กล่อง", "แพ็ค", "แผง", "ขวด", "ถุง", "กระป๋อง", "ชุด",
    "มล", "ลิตร", "กรัม", "กก",
    "ml", "mL", "ML", "l", "L", "g", "G", "kg", "KG"
]
UNIT_RE = r"(" + "|".join(map(re.escape, UNIT_VARIANTS)) + r")"
SIZE_RE = re.compile(rf"(?<!\d)(\d{{1,6}})\s*{UNIT_RE}(?!\w)", re.IGNORECASE)

# วันที่แบบตรง ๆ (รองรับ / - .)
DATE_ANY = re.compile(r"(?<!\d)(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})(?!\d)")

# กันราคาหลุดไปที่อยู่/โทร
DENY_ADDR = re.compile(r"(โทร|ถนน|แขวง|เขต|จังหวัด|กรุงเทพ|บริษัท|จำกัด|www|http)", re.IGNORECASE)
PHONE_LIKE = re.compile(r"\b0\d[-\s]?\d{6,}\b")
PRICE_HINT_RE = re.compile(r"(ราคา|บาท|ระบุ|จุดขาย|ณ\s*จุดขาย|ขาย)", re.IGNORECASE)
MONEY_RE = re.compile(r"(?<!\d)(\d{1,7}(?:\.\d{1,2})?)(?!\d)")

# -----------------------------
# Date extraction (fuzzy)
# -----------------------------
def _to_ce_year(y: int) -> int:
    # ถ้าเป็น พ.ศ. (>=2400) แปลงเป็น ค.ศ.
    return y - 543 if y >= 2400 else y

def fix_date(t: str):
    """
    คืน dd/mm/yyyy (ค.ศ.) ให้มากที่สุด
    รองรับ:
    - 28/10/2024, 28-10-2024, 28.10.2024
    - 28/10/24
    - กรณี OCR เพี้ยน: 28/1O/2O24, 2 8 / 1 0 / 2 0 2 4, 28102024
    """
    if not t:
        return None

    # 1) ลองแบบ regex ปกติ
    t1 = norm_numeric_context(t)
    m = DATE_ANY.search(t1)
    if m:
        dd_i = int(m.group(1))
        mm_i = int(m.group(2))
        yy_s = m.group(3)
        y = int(yy_s)
        if len(yy_s) == 2:
            y = 2000 + y
        elif len(yy_s) == 3:
            y = 2000 + (y % 100)
        y = _to_ce_year(y)
        if 1 <= dd_i <= 31 and 1 <= mm_i <= 12:
            return f"{dd_i:02d}/{mm_i:02d}/{y:04d}"

    # 2) แบบ fuzzy: ดึงเลขทั้งหมดออกมาแล้วประกอบ
    # ตัวอย่าง: "2 8 / 1 0 / 2 O 2 4" -> "28102024"
    digits = re.findall(r"\d", t1)
    if len(digits) >= 8:
        s = "".join(digits)
        # ลองอ่านแบบ ddmmyyyy
        dd = int(s[0:2])
        mm = int(s[2:4])
        yy = int(s[4:8])
        if 1 <= dd <= 31 and 1 <= mm <= 12:
            yy = _to_ce_year(yy)
            return f"{dd:02d}/{mm:02d}/{yy:04d}"

        # เผื่อเป็น yyyymmdd
        yy2 = int(s[0:4])
        mm2 = int(s[4:6])
        dd2 = int(s[6:8])
        if 1 <= dd2 <= 31 and 1 <= mm2 <= 12:
            yy2 = _to_ce_year(yy2)
            return f"{dd2:02d}/{mm2:02d}/{yy2:04d}"

    # 3) กรณีมีแค่ 6 หลัก (ddmmyy)
    if len(digits) == 6:
        s = "".join(digits)
        dd = int(s[0:2])
        mm = int(s[2:4])
        yy = int(s[4:6])
        if 1 <= dd <= 31 and 1 <= mm <= 12:
            y = 2000 + yy
            return f"{dd:02d}/{mm:02d}/{y:04d}"

    return None

def is_digits_spaced(t: str) -> bool:
    return bool(re.fullmatch(r"[\d\s]+", t or ""))

# -----------------------------
# Main extractor
# -----------------------------
def extract_fields(lines):
    """
    lines: list of dict from ocr_crops:
      {text, bbox[x1,y1,x2,y2], y_center, crop_path}
    return:
      {name, barcode, size, price, mfg}
    """
    items = []
    for it in lines:
        txt = norm(it.get("text", ""))
        if not txt:
            continue
        bbox = it.get("bbox", [0, 0, 0, 0])
        items.append({**it, "text": txt, "bbox": bbox})

    out = {"name": "", "barcode": "", "size": "", "price": "", "mfg": ""}

    # ---- barcode ----
    bc_cand = []
    for it in items:
        t = norm_numeric_context(it["text"])
        t2 = re.sub(r"\s+", "", t)
        if BARCODE_RE.fullmatch(t2):
            x1, y1, x2, y2 = it["bbox"]
            bc_cand.append(((x2 - x1), t2, y1))
    if bc_cand:
        bc_cand.sort(reverse=True)
        out["barcode"] = bc_cand[0][1]

    # ---- mfg (date) ----
    mfg_cand = []
    for it in items:
        d = fix_date(it["text"])
        if d:
            mfg_cand.append((it["bbox"][1], d))
    if mfg_cand:
        mfg_cand.sort(key=lambda x: x[0])
        out["mfg"] = mfg_cand[0][1]

    # ---- size ----
    size_cand = []
    for it in items:
        t = norm_numeric_context(it["text"])
        # ถ้าไม่มีเลขเลย ไม่ใช่ size
        if not contains_any_digit(t):
            continue
        m = SIZE_RE.search(t)
        if m:
            qty = m.group(1)
            unit = m.group(2)
            # normalize หน่วยเพี้ยน "ช็น/ซิ้น/ชน/ชิน" -> "ชิ้น"
            if unit in ["ช็น", "ซิ้น", "ชน", "ชิน", "ชํ้น", "ช้้น", "ช่ิน", "ชิ่้น"]:
                unit = "ชิ้น"
            val = f"{qty}{unit}"
            size_cand.append((it["bbox"][1], val))
    if size_cand:
        size_cand.sort(key=lambda x: x[0])
        out["size"] = size_cand[0][1]

    # ---- price ----
    price_cand = []
    for it in items:
        t = it["text"]
        tn = norm_numeric_context(t)

        if fix_date(tn):
            continue
        if DENY_ADDR.search(t) or PHONE_LIKE.search(tn):
            continue
        if len(t) > 100:
            continue

        has_hint = bool(PRICE_HINT_RE.search(t))
        has_money = bool(MONEY_RE.search(tn))
        if has_hint or has_money:
            score = 2 if has_hint else 1
            if "บาท" in t:
                score += 1
            price_cand.append((score, it["bbox"][1], t.strip()))

    if price_cand:
        price_cand.sort(key=lambda x: (-x[0], x[1]))
        out["price"] = price_cand[0][2]

    # ---- name ----
    # 1) ถ้ามีบรรทัดคล้าย "ชื่อสินค้า:" (แม้ OCR เพี้ยน) ให้เอาบรรทัดถัด ๆ
    # 2) ไม่งั้นเลือกบรรทัดบน ๆ ที่ไม่ใช่ barcode/size/price/mfg
    name_cand = []

    # เพิ่มความทน: ยอมรับ "ชื่อ" เพี้ยน เช่น ขือ/ชือ
    name_hint = re.compile(r"(ชื่อ|ชือ|ขือ)\s*สินค้า", re.IGNORECASE)

    for it in items:
        t = it["text"]
        y = it["bbox"][1]

        if ":" in t and name_hint.search(t):
            v = norm(t.split(":", 1)[1])
            if v and not is_digits_spaced(v) and not fix_date(v):
                out["name"] = v
                break

        name_cand.append((y, it["bbox"][0], t))

    if not out["name"]:
        def bad_for_name(t: str) -> bool:
            tt = norm(t)
            ttn = norm_numeric_context(tt)

            if is_digits_spaced(tt) or re.sub(r"\s+", "", ttn).isdigit():
                return True
            if fix_date(ttn):
                return True
            if SIZE_RE.search(ttn):
                return True
            if any(k in tt for k in ["ราคา", "บาท", "ระบุ", "จุดขาย", "ณ", "MFG", "วันที่ผลิต", "ผลิต", "โทร", "ถนน", "บริษัท", "จำกัด", "www", "http"]):
                return True
            if not re.search(r"[ก-๙A-Za-z]", tt):
                return True
            if len(tt) > 100:
                return True
            return False

        name_cand.sort(key=lambda x: (x[0], x[1]))
        for _, _, t in name_cand:
            if bad_for_name(t):
                continue
            out["name"] = t
            break

    return out
