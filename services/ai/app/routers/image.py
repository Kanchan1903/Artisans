"""AI Image Studio router: background removal, lighting balance, 1:1 square & 4:5 portrait crop."""
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from app.image.enhancer import process_artisan_image, generate_image_variations

router = APIRouter(prefix="/ai", tags=["AI Image Studio"])


@router.post("/enhance-image")
async def enhance_image(
    file: UploadFile = File(...),
    aspect_ratio: str = Form("1:1"),
):
    """
    Transform raw artisan smartphone photo into studio-grade e-commerce product asset:
    - Removes messy rural workshop background (rembg/GrabCut)
    - Fixes color cast, white balance and shadow brightness (OpenCV CLAHE)
    - Generates 1:1 square or 4:5 portrait white canvas
    """
    try:
        image_bytes = await file.read()
        out_bytes, data_uri = process_artisan_image(image_bytes, aspect_ratio=aspect_ratio)

        width, height = (1024, 1024) if aspect_ratio == "1:1" else (1024, 1280)
        return {
            "status": "success",
            "aspect_ratio": aspect_ratio,
            "width": width,
            "height": height,
            "enhanced_image_base64": data_uri,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image enhancement error: {str(e)}")


@router.post("/generate-variations")
async def generate_variations_endpoint(
    file: UploadFile = File(...),
    count: int = Form(12),
):
    """
    Generate 10–15 studio image variations with diverse backgrounds, lighting, and angles
    so the artisan can select 3–4 high quality images for the e-commerce listing.
    """
    try:
        image_bytes = await file.read()
        variations = generate_image_variations(image_bytes, count=count)
        return {
            "status": "success",
            "total_variations": len(variations),
            "variations": variations,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image variation error: {str(e)}")
