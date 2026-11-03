"""Safe image decoding and normalization for the product AI pipeline."""
from __future__ import annotations

import io

import numpy as np
from PIL import Image, ImageOps


MAX_IMAGE_PIXELS = 40_000_000
MAX_PROCESSING_DIMENSION = 2560
IMAGE_FORMATS = {
    "JPEG": ("image/jpeg", ".jpg"),
    "PNG": ("image/png", ".png"),
    "WEBP": ("image/webp", ".webp"),
}


def prepare_product_image(raw: bytes, declared_type: str) -> tuple[bytes, str, str]:
    """Apply EXIF orientation, bounded resizing and pixel validation.

    This creates the agent's processing copy. The separate product upload route
    retains the original bytes unchanged for the artisan's listing.
    """
    if not raw:
        raise ValueError("Uploaded image is empty")

    try:
        with Image.open(io.BytesIO(raw)) as source:
            image_format = (source.format or "").upper()
            if image_format not in IMAGE_FORMATS:
                raise ValueError("Use a JPEG, PNG, or WebP image")
            content_type, extension = IMAGE_FORMATS[image_format]
            if declared_type and declared_type.lower() != content_type:
                raise ValueError("Image content does not match its declared file type")
            image = ImageOps.exif_transpose(source)
            if image.width <= 0 or image.height <= 0 or image.width * image.height > MAX_IMAGE_PIXELS:
                raise ValueError("Image dimensions are invalid or too large")
            has_alpha = "A" in image.getbands() or "transparency" in image.info
            mode = "RGBA" if has_alpha and image_format != "JPEG" else "RGB"
            image.thumbnail(
                (MAX_PROCESSING_DIMENSION, MAX_PROCESSING_DIMENSION),
                Image.Resampling.LANCZOS,
            )
            image = image.convert(mode)
            pixels = np.asarray(image)
    except (Image.DecompressionBombError, OSError) as exc:
        raise ValueError("The uploaded image could not be decoded") from exc

    expected_channels = 4 if mode == "RGBA" else 3
    if (
        pixels.ndim != 3
        or pixels.shape[2] != expected_channels
        or pixels.dtype != np.uint8
    ):
        raise ValueError("Image pixel data is invalid")

    normalized = Image.fromarray(np.ascontiguousarray(pixels), mode=mode)
    output = io.BytesIO()
    if image_format == "JPEG":
        normalized.save(output, format="JPEG", quality=92, optimize=True, progressive=True)
    elif image_format == "PNG":
        normalized.save(output, format="PNG", optimize=True)
    else:
        normalized.save(output, format="WEBP", quality=92, method=4)
    return output.getvalue(), content_type, extension
