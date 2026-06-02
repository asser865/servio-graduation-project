# DEPRECATED — DO NOT MOUNT THIS ROUTER.
#
# This module is a stale duplicate of routes/room_analysis.py.
# It uses Groq/Llama-4 (room_finishing/services/gemini_service.py) instead of
# the canonical Gemini Vision pipeline. If ever mounted in main.py it would
# shadow POST /ai/analyze-room with a completely different model and no SD render.
#
# Kept for reference only. Safe to delete once the project is stable.
#
# --- DO NOT add `app.include_router(room_finishing_router)` to main.py ---

raise ImportError(
    "room_finishing.routes.room_analysis is deprecated and must not be imported. "
    "Use routes.room_analysis instead."
)

from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from room_finishing.services.gemini_service import analyze_room
from room_finishing.utils.image_utils import prepare_image, validate_image
import json

router = APIRouter()

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB


@router.post("/ai/analyze-room")
async def analyze_room_endpoint(
    image: UploadFile = File(..., description="Room photo — JPEG or PNG of the empty room"),
    length_m: float = Form(..., description="Room length in meters (e.g. 5.0)"),
    width_m: float  = Form(..., description="Room width in meters (e.g. 4.0)"),
    height_m: float = Form(..., description="Room height in meters (e.g. 2.8)"),
    budget_egp: int = Form(..., description="User's total budget in Egyptian Pounds"),
    style: str      = Form(default="modern", description="Preferred style: modern, classic, minimalist, etc.")
):
    # — Validate file type ————————————————————————————————————————————
    if image.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {image.content_type}. Use JPEG or PNG."
        )

    # — Read and check file size ——————————————————————————————————————
    image_bytes = await image.read()

    if len(image_bytes) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=400,
            detail="Image file is too large. Maximum size is 10 MB."
        )

    # — Validate it is actually an image ——————————————————————————————
    if not validate_image(image_bytes):
        raise HTTPException(
            status_code=400,
            detail="The uploaded file is not a valid image."
        )

    # — Validate room dimensions ———————————————————————————————————————
    if not (1.0 <= length_m <= 50.0):
        raise HTTPException(status_code=400, detail="Length must be between 1 and 50 meters.")
    if not (1.0 <= width_m <= 50.0):
        raise HTTPException(status_code=400, detail="Width must be between 1 and 50 meters.")
    if not (2.0 <= height_m <= 6.0):
        raise HTTPException(status_code=400, detail="Height must be between 2 and 6 meters.")
    if budget_egp < 1000:
        raise HTTPException(status_code=400, detail="Budget must be at least EGP 1,000.")

    # — Call Gemini Vision API ———————————————————————————————————————
    try:
        processed_bytes = prepare_image(image_bytes)

        result = analyze_room(
            image_bytes=processed_bytes,
            length_m=length_m,
            width_m=width_m,
            height_m=height_m,
            budget_egp=budget_egp,
            style_preference=style
        )

        return JSONResponse(content={
            "status": "success",
            "data": result
        })

    except json.JSONDecodeError:
        raise HTTPException(
            status_code=500,
            detail="The AI returned an unexpected response format. Please try again."
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Analysis failed: {str(e)}"
        )
