import base64
import io
from PIL import Image


def prepare_image(image_bytes: bytes) -> bytes:
    """
    Resize image to max 1600px on longest side and return as JPEG bytes.
    Gemini works best with images under 1600px — larger images cost more tokens.
    """
    img = Image.open(io.BytesIO(image_bytes))

    # Convert any format (PNG, WEBP, HEIC, etc.) to RGB JPEG
    if img.mode != "RGB":
        img = img.convert("RGB")

    # Resize if too large
    max_size = 1600
    ratio = min(max_size / img.width, max_size / img.height)
    if ratio < 1:
        new_w = int(img.width * ratio)
        new_h = int(img.height * ratio)
        img = img.resize((new_w, new_h), Image.LANCZOS)

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
