from fastapi import APIRouter, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from services.gemini_service import analyze_room
from services.stable_diffusion_service import generate_finished_room, budget_to_tier
from services.vendor_enrichment import enrich_with_vendors, get_vendor_db_connection
from utils.image_utils import prepare_image, prepare_image_for_sd, validate_image
import json

router = APIRouter()

ALLOWED_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
MAX_FILE_SIZE  = 10 * 1024 * 1024  # 10 MB


def _build_consistency_envelope(
    user_style: str,
    budget_egp: int,
    floor_area_m2: float,
    best_plan: dict,
    sd_prompt_used: str,
) -> dict:
    """
    Links Gemini output to SD generation so the client can verify visual ↔ cost consistency.
    Also flags any mismatches as warnings.
    """
    materials  = best_plan.get("materials", [])
    primary_flooring = next(
        (m["name"] for m in materials if m.get("category") == "flooring"), ""
    )
    primary_wall = next(
        (m["name"] for m in materials if m.get("category") in ("walls", "painting")), ""
    )

    warnings = []
    prompt_lower = sd_prompt_used.lower()

    if primary_flooring and primary_flooring.split()[0].lower() not in prompt_lower:
        warnings.append(f"Primary flooring '{primary_flooring}' not reflected in render prompt")

    if user_style.lower() not in prompt_lower:
        warnings.append(f"User style '{user_style}' not in render prompt")

    gemini_total = best_plan.get("total_cost_egp", 0)
    vendor_total = best_plan.get("vendor_adjusted_total_egp", gemini_total)
    if gemini_total > 0:
        drift = abs(vendor_total - gemini_total) / gemini_total
        if drift > 0.30:
            warnings.append(
                f"Cost drift {abs(vendor_total - gemini_total):,.0f} EGP "
                f"({drift * 100:.0f}%) exceeds 30% — vendor prices diverge from Gemini estimate"
            )

    return {
        "style_used":        user_style,
        "budget_tier":       budget_to_tier(budget_egp, floor_area_m2),
        "floor_area_m2":     floor_area_m2,
        "primary_flooring":  primary_flooring,
        "primary_wall":      primary_wall,
        "sd_prompt_used":    sd_prompt_used,
        "gemini_total_cost": gemini_total,
        "vendor_adjusted_cost": vendor_total,
        "consistency_warnings": warnings,
    }


@router.post("/ai/analyze-room")
async def analyze_room_endpoint(
    image:          UploadFile = File(...),
    length_m:       float      = Form(...),
    width_m:        float      = Form(...),
    height_m:       float      = Form(...),
    budget_egp:     int        = Form(...),
    style:          str        = Form(default="modern"),
    include_render: bool       = Form(default=True),
):
    if image.content_type not in ALLOWED_TYPES:
        raise HTTPException(400, "Unsupported file type. Use JPEG or PNG.")

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

    floor_area_m2 = round(length_m * width_m, 2)

    try:
        # ── 1. Gemini Vision: analyse room + generate 3 finishing plans ──────
        gemini_bytes = prepare_image(image_bytes, max_size=1600)
        result = analyze_room(
            image_bytes=gemini_bytes,
            length_m=length_m,
            width_m=width_m,
            height_m=height_m,
            budget_egp=budget_egp,
            style_preference=style,
        )

        # ── 2. Vendor enrichment ──────────────────────────────────────────────
        # Always runs: with DB → real prices; without DB → fallback vendor names + price table
        db_conn = get_vendor_db_connection()
        try:
            result["finishing_plans"] = enrich_with_vendors(
                result["finishing_plans"], db_conn
            )
            best_plan_name = result.get("recommended_plan", "")
            for plan in result["finishing_plans"]:
                if plan["plan_name"] == best_plan_name:
                    plan["vendor_adjusted_total_egp"] = plan.get("total_cost_egp", 0)
        except Exception as enrich_err:
            print(f"Vendor enrichment failed (non-fatal): {enrich_err}")
        finally:
            if db_conn is not None:
                db_conn.close()

        # ── 3. Select recommended plan ────────────────────────────────────────
        recommended_plan = next(
            (p for p in result["finishing_plans"]
             if p["plan_name"] == result.get("recommended_plan")),
            result["finishing_plans"][0],
        )

        # ── 4. Stable Diffusion render (optional, ~20-45 s on CPU) ────────────
        generated_image_b64 = None
        sd_prompt_used      = ""

        if include_render:
            sd_bytes = prepare_image_for_sd(image_bytes)
            generated_image_b64, sd_prompt_used = generate_finished_room(
                room_image_bytes=sd_bytes,
                room_analysis=result["room_analysis"],
                finishing_plan=recommended_plan,
                user_style=style,
                budget_egp=budget_egp,
                floor_area_m2=floor_area_m2,
            )

        # ── 5. Consistency envelope ───────────────────────────────────────────
        consistency_envelope = _build_consistency_envelope(
            user_style=style,
            budget_egp=budget_egp,
            floor_area_m2=floor_area_m2,
            best_plan=recommended_plan,
            sd_prompt_used=sd_prompt_used,
        )

        return JSONResponse(content={
            "status": "success",
            "data":   result,
            "generated_room_image":  generated_image_b64,
            "consistency_envelope":  consistency_envelope,
        })

    except json.JSONDecodeError:
        raise HTTPException(500, "AI returned unexpected format. Please try again.")
    except Exception as e:
        raise HTTPException(500, f"Analysis failed: {str(e)}")
