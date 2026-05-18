from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from services.gemini_service import analyze_room
from services.stable_diffusion_service import generate_finished_room
from utils.image_utils import prepare_image, prepare_image_for_sd, validate_image
import json

router = APIRouter()

ALLOWED_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
MAX_FILE_SIZE  = 10 * 1024 * 1024  # 10 MB


@router.post("/ai/analyze-room")
async def analyze_room_endpoint(
    image:      UploadFile = File(...),
    length_m:   float      = Form(...),
    width_m:    float      = Form(...),
    height_m:   float      = Form(...),
    budget_egp: int        = Form(...),
    style:      str        = Form(default="modern")
):
    if image.content_type not in ALLOWED_TYPES:
        raise HTTPException(400, f"Unsupported file type. Use JPEG or PNG.")

    image_bytes = await image.read()

    if len(image_bytes) > MAX_FILE_SIZE:
        raise HTTPException(400, "Image too large. Maximum 10 MB.")

    if not validate_image(image_bytes):
        raise HTTPException(400, "Invalid image file.")

    if not (1.0 <= length_m <= 50.0):
        raise HTTPException(400, "Length must be between 1 and 50 meters.")
    if not (1.0 <= width_m <= 50.0):
        raise HTTPException(400, "Width must be between 1 and 50 meters.")
    if not (2.0 <= height_m <= 6.0):
        raise HTTPException(400, "Height must be between 2 and 6 meters.")
    if budget_egp < 1000:
        raise HTTPException(400, "Budget must be at least EGP 1,000.")

    try:
        # Step 1: Gemini Vision — analyze room and generate finishing plan
        gemini_bytes = prepare_image(image_bytes, max_size=1600)
        result = analyze_room(
            image_bytes=gemini_bytes,
            length_m=length_m,
            width_m=width_m,
            height_m=height_m,
            budget_egp=budget_egp,
            style_preference=style
        )

        # Step 2: Stable Diffusion — generate visual render of finished room
        sd_bytes = prepare_image_for_sd(image_bytes)

        recommended_plan = next(
            (p for p in result["finishing_plans"]
             if p["plan_name"] == result["recommended_plan"]),
            result["finishing_plans"][0]
        )

        generated_image_b64 = generate_finished_room(
            room_image_bytes=sd_bytes,
            room_analysis=result["room_analysis"],
            finishing_plan=recommended_plan,
            strength=0.65,
            steps=30
        )

        return JSONResponse(content={
            "status": "success",
            "data":   result,
            "generated_room_image": generated_image_b64
        })

    except json.JSONDecodeError:
        raise HTTPException(500, "AI returned unexpected format. Please try again.")
    except Exception as e:
        raise HTTPException(500, f"Analysis failed: {str(e)}")
