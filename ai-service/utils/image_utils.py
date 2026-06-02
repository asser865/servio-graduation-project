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


def prepare_image_for_sd(image_bytes: bytes, target_size: int = 768) -> bytes:
    """
    Resize image preserving aspect ratio, then pad to a square with black bars.

    Replaces the old hard 768×512 resize that destroyed room geometry.
    Room proportions affect perceived furniture scale — preserving them
    prevents SD from generating rooms with impossible layouts.
    """
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    ratio = min(target_size / img.width, target_size / img.height)
    new_w = int(img.width * ratio)
    new_h = int(img.height * ratio)
    img = img.resize((new_w, new_h), Image.LANCZOS)

    padded = Image.new("RGB", (target_size, target_size), (0, 0, 0))
    offset_x = (target_size - new_w) // 2
    offset_y = (target_size - new_h) // 2
    padded.paste(img, (offset_x, offset_y))

    buf = io.BytesIO()
    padded.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


def validate_image(image_bytes: bytes) -> bool:
    """Check the uploaded file is a valid image."""
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img.verify()
        return True
    except Exception:
        return False
