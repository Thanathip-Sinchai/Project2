import os
import cv2
import easyocr

def _ensure_dir(p):
    os.makedirs(p, exist_ok=True)

def _poly_to_bbox(poly):
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    return [int(min(xs)), int(min(ys)), int(max(xs)), int(max(ys))]

def _preprocess(img):
    g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    g = cv2.bilateralFilter(g, 7, 50, 50)
    g = cv2.normalize(g, None, 0, 255, cv2.NORM_MINMAX)
    th = cv2.adaptiveThreshold(
        g, 255,
        cv2.ADAPTIVE_THRESH_MEAN_C,
        cv2.THRESH_BINARY,
        31, 10
    )
    return th

def detect_and_crop(
    image_path,
    out_dir="tmp_crops",
    save_annotated=True,
    use_gpu=False,
    languages=("th", "en"),
    min_box_area=350
):
    _ensure_dir(out_dir)

    img = cv2.imread(image_path)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")

    reader = easyocr.Reader(list(languages), gpu=use_gpu)

    # detect on preprocessed image (better boxes)
    img_pre = _preprocess(img)
    dets = reader.readtext(img_pre, detail=1)

    crops = []
    annotated = img.copy()
    base = os.path.splitext(os.path.basename(image_path))[0]

    for i, (poly, text, conf) in enumerate(dets):
        poly = [[int(p[0]), int(p[1])] for p in poly[:4]]
        x1, y1, x2, y2 = _poly_to_bbox(poly)

        if (x2 - x1) * (y2 - y1) < min_box_area:
            continue

        crop = img[y1:y2, x1:x2]
        if crop.size == 0:
            continue

        crop_path = os.path.join(out_dir, f"{base}_{i}.png")
        cv2.imwrite(crop_path, crop)

        y_center = (y1 + y2) / 2
        crops.append({
            "crop_path": crop_path,
            "bbox": [x1, y1, x2, y2],
            "y_center": y_center,
        })

        if save_annotated:
            cv2.rectangle(annotated, (x1, y1), (x2, y2), (0, 255, 0), 2)

    if save_annotated:
        ann_path = os.path.join(out_dir, f"{base}_annotated.png")
        cv2.imwrite(ann_path, annotated)

    crops.sort(key=lambda x: x["y_center"])
    return crops
