import io
from PIL import Image


def prepare_image(image_bytes: bytes, max_size: int = 1600) -> bytes:
    """Resize image to max_size on longest side and return as JPEG bytes."""
    img = Image.open(io.BytesIO(image_bytes))

    if img.mode != "RGB":
        img = img.convert("RGB")

    ratio = min(max_size / img.width, max_size / img.height)
    if ratio < 1:
        new_w = int(img.width * ratio)
        new_h = int(img.height * ratio)
        img = img.resize((new_w, new_h), Image.LANCZOS)

    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=85)
    return buffer.getvalue()


def prepare_image_for_sd(image_bytes: bytes) -> bytes:
    """Resize to 768x512 for Stable Diffusion input."""
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img = img.resize((768, 512))
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=85)
    return buffer.getvalue()


def validate_image(image_bytes: bytes) -> bool:
    """Check the uploaded file is a valid image."""
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img.verify()
        return True
    except Exception:
        return False
