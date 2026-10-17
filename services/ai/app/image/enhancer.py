"""AI Image Studio: Background removal, white balance, CLAHE lighting fix, and 1:1 / 4:5 cropping."""
import io
import base64
import numpy as np
import cv2
from PIL import Image
from app.config import ai_settings


def remove_background(image: Image.Image) -> Image.Image:
    """Remove background using rembg (U2-Net) or intelligent OpenCV GrabCut fallback."""
    # Only call rembg when not in mock mode to avoid downloading large models during test runs
    if not ai_settings.AI_MOCK_MODE:
        try:
            import rembg
            return rembg.remove(image)
        except (ImportError, Exception, SystemExit):
            pass

    # High-speed OpenCV GrabCut / Saliency Segmentation
    cv_img = cv2.cvtColor(np.array(image.convert("RGB")), cv2.COLOR_RGB2BGR)
    h, w = cv_img.shape[:2]

    mask = np.zeros((h, w), np.uint8)
    bgd_model = np.zeros((1, 65), np.float64)
    fgd_model = np.zeros((1, 65), np.float64)

    # Margin rectangle for bounding foreground craft object
    margin_x = max(int(w * 0.05), 1)
    margin_y = max(int(h * 0.05), 1)
    rect = (margin_x, margin_y, w - 2 * margin_x, h - 2 * margin_y)

    try:
        cv2.grabCut(cv_img, mask, rect, bgd_model, fgd_model, 2, cv2.GC_INIT_WITH_RECT)
        mask2 = np.where((mask == 2) | (mask == 0), 0, 1).astype("uint8")
        rgba = cv2.cvtColor(cv_img, cv2.COLOR_BGR2BGRA)
        rgba[:, :, 3] = mask2 * 255
        return Image.fromarray(cv2.cvtColor(rgba, cv2.COLOR_BGRA2RGBA))
    except Exception:
        return image.convert("RGBA")


def correct_lighting_and_white_balance(image: Image.Image) -> Image.Image:
    """Correct uneven lighting, apply CLAHE contrast enhancement, and auto white balance."""
    cv_img = cv2.cvtColor(np.array(image.convert("RGB")), cv2.COLOR_RGB2BGR)

    # 1. Auto White Balance via Gray World Assumption
    result = cv_img.copy().astype(np.float32)
    avg_b = np.mean(result[:, :, 0])
    avg_g = np.mean(result[:, :, 1])
    avg_r = np.mean(result[:, :, 2])
    avg_gray = (avg_b + avg_g + avg_r) / 3.0

    if avg_b > 0 and avg_g > 0 and avg_r > 0:
        result[:, :, 0] = np.clip(result[:, :, 0] * (avg_gray / avg_b), 0, 255)
        result[:, :, 1] = np.clip(result[:, :, 1] * (avg_gray / avg_g), 0, 255)
        result[:, :, 2] = np.clip(result[:, :, 2] * (avg_gray / avg_r), 0, 255)

    balanced = result.astype(np.uint8)

    # 2. CLAHE (Contrast Limited Adaptive Histogram Equalization) on Lightness channel
    lab = cv2.cvtColor(balanced, cv2.COLOR_BGR2LAB)
    l_channel, a_channel, b_channel = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced_l = clahe.apply(l_channel)
    merged_lab = cv2.merge([enhanced_l, a_channel, b_channel])
    enhanced_bgr = cv2.cvtColor(merged_lab, cv2.COLOR_LAB2BGR)

    return Image.fromarray(cv2.cvtColor(enhanced_bgr, cv2.COLOR_BGR2RGB))


def create_studio_composition(
    foreground_rgba: Image.Image,
    target_size: tuple[int, int] = (1024, 1024),
    bg_color: tuple[int, int, int] = (255, 255, 255),
    padding_ratio: float = 0.12,
) -> Image.Image:
    """Composite the segmented artisan craft onto a pure studio background with gentle drop-shadow."""
    target_w, target_h = target_size
    max_w = int(target_w * (1.0 - 2 * padding_ratio))
    max_h = int(target_h * (1.0 - 2 * padding_ratio))

    # Resize foreground preserving aspect ratio
    fg = foreground_rgba.copy()
    fg.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)

    # Create solid white canvas
    canvas = Image.new("RGBA", target_size, bg_color + (255,))

    # Center placement
    offset_x = (target_w - fg.width) // 2
    offset_y = (target_h - fg.height) // 2

    canvas.paste(fg, (offset_x, offset_y), mask=fg)
    return canvas.convert("RGB")


def process_artisan_image(
    image_bytes: bytes,
    aspect_ratio: str = "1:1",
) -> tuple[bytes, str]:
    """
    Complete studio pipeline:
    1. Decode raw artisan photo
    2. Correct white balance & lighting
    3. Remove background
    4. Composite onto pristine 1:1 or 4:5 white studio canvas
    Returns: (output_jpeg_bytes, base64_data_uri)
    """
    raw_img = Image.open(io.BytesIO(image_bytes))

    # Lighting correction
    lit_img = correct_lighting_and_white_balance(raw_img)

    # Background removal
    cutout = remove_background(lit_img)

    # Canvas sizing
    if aspect_ratio == "4:5":
        canvas_size = (1024, 1280)
    else:
        canvas_size = (1024, 1024)

    studio_img = create_studio_composition(cutout, target_size=canvas_size)

    # Encode to JPEG
    buf = io.BytesIO()
    studio_img.save(buf, format="JPEG", quality=92, optimize=True)
    out_bytes = buf.getvalue()
    b64_str = base64.b64encode(out_bytes).decode("utf-8")
    data_uri = f"data:image/jpeg;base64,{b64_str}"

    return out_bytes, data_uri


def create_variation_composition(
    foreground_rgba: Image.Image,
    target_size: tuple[int, int] = (1024, 1024),
    bg_color: tuple[int, int, int] = (255, 255, 255),
    zoom: float = 1.0,
    has_shadow: bool = False,
) -> Image.Image:
    """Compose foreground onto styled background with optional contact shadow and scale."""
    target_w, target_h = target_size
    base_padding = 0.12 / zoom
    max_w = int(target_w * max(0.1, (1.0 - 2 * base_padding)))
    max_h = int(target_h * max(0.1, (1.0 - 2 * base_padding)))

    fg = foreground_rgba.copy()
    fg.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", target_size, bg_color + (255,))

    offset_x = (target_w - fg.width) // 2
    offset_y = (target_h - fg.height) // 2

    if has_shadow:
        from PIL import ImageDraw, ImageFilter
        shadow_w = int(fg.width * 0.85)
        shadow_h = max(int(fg.height * 0.10), 12)
        shadow_x0 = (target_w - shadow_w) // 2
        shadow_y0 = min(offset_y + fg.height - shadow_h // 2, target_h - shadow_h - 10)
        shadow_mask = Image.new("RGBA", target_size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(shadow_mask)
        draw.ellipse(
            [shadow_x0, shadow_y0, shadow_x0 + shadow_w, shadow_y0 + shadow_h],
            fill=(40, 30, 25, 75),
        )
        shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(14))
        canvas = Image.alpha_composite(canvas, shadow_mask)

    canvas.paste(fg, (offset_x, offset_y), mask=fg)
    return canvas.convert("RGB")


def generate_image_variations(
    image_bytes: bytes,
    count: int = 12,
) -> list[dict]:
    """
    Generate 10-15 studio image variations for the artisan to choose 3-4 from.
    Includes clean white, warm terracotta, rustic wood, linen canvas, morning sunlight,
    sandstone pedestal, festive glow, indigo contrast, macro detail, and soft shadows.
    """
    raw_img = Image.open(io.BytesIO(image_bytes))
    lit_img = correct_lighting_and_white_balance(raw_img)
    cutout = remove_background(lit_img)

    styles = [
        {"id": "var_1", "style": "white_studio", "title": "Pristine White Studio", "title_hi": "शुद्ध सफेद स्टूडियो", "title_mr": "शुद्ध पांढरी स्टुडिओ", "bg_color": (255, 255, 255), "zoom": 1.0, "shadow": False},
        {"id": "var_2", "style": "warm_terracotta", "title": "Warm Terracotta Studio", "title_hi": "मिट्टी का गर्म रंग", "title_mr": "मातीचा उबदार रंग", "bg_color": (246, 236, 230), "zoom": 1.0, "shadow": True},
        {"id": "var_3", "style": "rustic_wood", "title": "Rustic Workshop Wood", "title_hi": "लकड़ी का देहाती आधार", "title_mr": "लाकडी हस्तकला पृष्ठभाग", "bg_color": (226, 212, 194), "zoom": 1.0, "shadow": True},
        {"id": "var_4", "style": "handloom_linen", "title": "Artisan Linen Canvas", "title_hi": "हस्तनिर्मित लिनन कैनवास", "title_mr": "पारंपरिक तागाचा कॅनव्हास", "bg_color": (248, 245, 238), "zoom": 1.0, "shadow": False},
        {"id": "var_5", "style": "morning_sunlight", "title": "Morning Sunlight Glow", "title_hi": "सुबह की सुनहरी धूप", "title_mr": "सकाळचा कोवळा सूर्यप्रकाश", "bg_color": (255, 248, 232), "zoom": 1.0, "shadow": True},
        {"id": "var_6", "style": "sandstone_pedestal", "title": "Sandstone Display Mount", "title_hi": "बलुआ पत्थर का चबूतरा", "title_mr": "वाळूचा दगडी चौथरा", "bg_color": (238, 232, 222), "zoom": 1.0, "shadow": True},
        {"id": "var_7", "style": "festive_glow", "title": "Festive Indian Aura", "title_hi": "त्योहारी उत्सव आभा", "title_mr": "उत्सवी सोनेरी आभा", "bg_color": (255, 242, 224), "zoom": 1.0, "shadow": True},
        {"id": "var_8", "style": "royal_indigo", "title": "Royal Indigo Contrast", "title_hi": "शाही नीला रंग", "title_mr": "शाही निळा रंग", "bg_color": (232, 237, 245), "zoom": 1.0, "shadow": False},
        {"id": "var_9", "style": "macro_detail", "title": "Macro Texture & Detail", "title_hi": "बारीक नक्काशी दृश्य", "title_mr": "बारीक नक्षीदार दृश्य (Macro)", "bg_color": (255, 255, 255), "zoom": 1.35, "shadow": False},
        {"id": "var_10", "style": "contact_shadow", "title": "Natural Floating Shadow", "title_hi": "प्राकृतिक कोमल छाया", "title_mr": "नैसर्गिक सावली (Soft Shadow)", "bg_color": (255, 255, 255), "zoom": 1.0, "shadow": True},
        {"id": "var_11", "style": "ceramic_pedestal", "title": "Minimal Ceramic White", "title_hi": "सिरेमिक सफेद मंच", "title_mr": "सिरेमिक पांढरा मंच", "bg_color": (252, 252, 254), "zoom": 1.0, "shadow": False},
        {"id": "var_12", "style": "museum_gallery", "title": "Museum Gallery Showcase", "title_hi": "संग्रहालय कला प्रदर्शन", "title_mr": "कला दालन प्रदर्शन (Museum)", "bg_color": (244, 244, 240), "zoom": 0.88, "shadow": True},
    ]

    variations = []
    for idx, s in enumerate(styles[:count]):
        comp = create_variation_composition(
            cutout,
            target_size=(1024, 1024),
            bg_color=s["bg_color"],
            zoom=s["zoom"],
            has_shadow=s["shadow"],
        )
        buf = io.BytesIO()
        comp.save(buf, format="JPEG", quality=88, optimize=True)
        b64 = base64.b64encode(buf.getvalue()).decode("utf-8")
        data_uri = f"data:image/jpeg;base64,{b64}"
        variations.append({
            "id": s["id"],
            "style": s["style"],
            "title": s["title"],
            "title_hi": s["title_hi"],
            "title_mr": s["title_mr"],
            "image_url": data_uri,
            "is_primary": (idx == 0),
        })

    return variations
