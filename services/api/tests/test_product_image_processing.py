import io

import pytest
from PIL import Image

from app.utils.product_image_processing import prepare_product_image


def png_bytes(size=(24, 16)):
    image = Image.new("RGBA", size, (194, 82, 49, 220))
    output = io.BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


def test_prepare_product_image_decodes_pixels_and_preserves_alpha():
    prepared, content_type, extension = prepare_product_image(png_bytes(), "image/png")

    with Image.open(io.BytesIO(prepared)) as result:
        assert result.format == "PNG"
        assert result.mode == "RGBA"
        assert result.size == (24, 16)
    assert content_type == "image/png"
    assert extension == ".png"


def test_prepare_product_image_rejects_mismatched_mime():
    with pytest.raises(ValueError, match="declared file type"):
        prepare_product_image(png_bytes(), "image/jpeg")


def test_prepare_product_image_rejects_corrupt_bytes():
    with pytest.raises(ValueError, match="decoded"):
        prepare_product_image(b"not an image", "image/jpeg")
