"""extract_fields.py
Rule-based extractor that consumes OCR outputs (text + bbox) and returns structured JSON fields:
- product_name
- price
- mfg_date
- exp_date
- barcode
- size/quantity

The extractor is heuristic-based (regex + keywords) tuned for Thai labels.
"""
import re
from typing import List, Dict

DATE_REGEX = re.compile(r"(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})")
BARCODE_REGEX = re.compile(r"\b(\d{6,13})\b")
PRICE_REGEX = re.compile(r"(?:ราคา\s*[:：]?\s*([\d,\.]+\s*(?:บาท|฿)?))", re.IGNORECASE)
SIZE_REGEX = re.compile(r"(ขนาดบรรจุ[:：]?\s*\d+\s*\w*|\b\d+\s*(?:g|ml|ชิ้น|pcs|ชิ้น)\b)", re.IGNORECASE)

KEYWORDS = {
    'product_name': ['ชื่อสินค้า', 'สินค้า', 'ผลิตภัณฑ์'],
    'mfg': ['วันผลิต', 'MFG', 'ผลิตวันที่', 'ผลิตเมื่อ'],
    'exp': ['หมดอายุ', 'EXP', 'EXP:','EXP.','Expiration'],
    'manufacturer': ['ผู้ผลิต', 'ผลิตโดย', 'Manufacturer'],
    'importer': ['ผู้นำเข้า', 'นำเข้า', 'Importer'],
    'warning': ['คำเตือน', 'ระวัง', 'ห้าม']
}

def find_by_keyword(ocr_lines, keywords):
    for kw in keywords:
        for item in ocr_lines:
            t = item['text']
            if kw in t:
                return item['text']
    return None

def extract(ocr_results: List[Dict]) -> Dict:
    # ocr_results: [{'text':..., 'bbox':..., 'crop':...}, ...]
    texts = [r['text'] for r in ocr_results]
    merged_text = '\n'.join(texts)

    out = {
        'product_name': None,
        'price': None,
        'mfg_date': None,
        'exp_date': None,
        'barcode': None,
        'size_quantity': None,
        'raw_text': merged_text
    }

    # 1) barcode (first high-confidence numeric sequence)
    bc = BARCODE_REGEX.search(merged_text)
    if bc:
        out['barcode'] = bc.group(1)

    # 2) dates (mfg / exp) - pick first for mfg and first after mfg for exp
    dates = DATE_REGEX.findall(merged_text)
    if dates:
        out['mfg_date'] = dates[0]
        if len(dates) > 1:
            out['exp_date'] = dates[1]

    # 3) price
    price = PRICE_REGEX.search(merged_text)
    if price:
        out['price'] = price.group(0)

    # 4) size / quantity
    size = SIZE_REGEX.search(merged_text)
    if size:
        out['size_quantity'] = size.group(0)

    # 5) product name - try to find keyword lines
    pn = find_by_keyword(ocr_results, KEYWORDS['product_name'])
    if pn:
        out['product_name'] = pn
    else:
        # fallback: choose the top-most longer text (heuristic)
        candidates = sorted(ocr_results, key=lambda x: x['bbox'][1])  # sort by y (top->down)
        for c in candidates:
            t = c['text'].strip()
            if len(t) > 5 and not any(k in t for k in ['วันที่','หมดอายุ','ราคา','บริษัท','ผู้นำเข้า']):
                out['product_name'] = t
                break

    return out

if __name__ == '__main__':
    import json, argparse, os
    parser = argparse.ArgumentParser()
    parser.add_argument('--ocr_json', required=True, help='ocr results json produced by ocr_trocr.py')
    parser.add_argument('--out', default='outputs/fields.json')
    args = parser.parse_args()
    ocr_results = json.load(open(args.ocr_json, 'r', encoding='utf-8'))
    fields = extract(ocr_results)
    os.makedirs(os.path.dirname(args.out) or '.', exist_ok=True)
    json.dump(fields, open(args.out, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print('Saved fields to', args.out)
