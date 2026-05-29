from google import genai
from google.genai import types
import json
import os
import time
from dotenv import load_dotenv

load_dotenv()
_client = None

# Fallback chain when upstream returns 503 UNAVAILABLE / 429 RESOURCE_EXHAUSTED.
# First entry is the preferred model. Each later entry is tried with a short
# backoff if the previous one is overloaded.
GEMINI_MODELS = [
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash",
]


def _generate_with_fallback(image_bytes: bytes, user_prompt: str, system_prompt: str):
    """Try each model in GEMINI_MODELS until one succeeds. Raises the last
    exception if every model is unavailable."""
    last_exc = None
    for idx, model_name in enumerate(GEMINI_MODELS):
        try:
            return _get_client().models.generate_content(
                model=model_name,
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                    user_prompt,
                ],
                config=types.GenerateContentConfig(system_instruction=system_prompt),
            )
        except Exception as exc:
            last_exc = exc
            msg = str(exc).upper()
            # Retry on transient upstream errors only — everything else
            # propagates immediately so we don't mask real bugs.
            if any(t in msg for t in ("UNAVAILABLE", "503", "RESOURCE_EXHAUSTED", "429", "OVERLOADED")):
                if idx < len(GEMINI_MODELS) - 1:
                    time.sleep(1.5 * (idx + 1))
                    continue
            raise
    raise last_exc  # all models exhausted


def _get_client():
    global _client
    if _client is None:
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key or api_key.startswith("AIzaSy_paste"):
            raise ValueError("GEMINI_API_KEY not set. Add your real key to ai-service/.env")
        _client = genai.Client(api_key=api_key)
    return _client

SYSTEM_PROMPT = """
You are an expert Egyptian interior designer and construction cost estimator.
You have deep knowledge of Egyptian building material prices in EGP as of 2024-2025,
specifically for Cairo and Giza markets.

When given a room photo and dimensions, analyze the room and produce a complete
finishing plan with 3 cost tiers.

STYLE ENFORCEMENT (critical):
When the user specifies a style preference, ALL 3 plans must use that style with
budget-appropriate materials:
- luxury:    marble/granite flooring min 800 EGP/m², ornate gypsum ceiling with chandelier,
             designer furniture, Venetian plaster or premium wallpaper walls
- modern:    large-format porcelain 350-600 EGP/m², recessed LED ceiling, matte paint walls,
             contemporary furniture
- classic:   decorative floor tile patterns, crown molding or decorative gypsum ceiling,
             warm wood furniture, textured paint or wallpaper
- minimal:   simple large-format tiles, flat plain ceiling, single-coat matte paint,
             minimal essential furniture only
Economy plan → style at budget-appropriate materials.
Standard plan → style at mid-tier materials.
Premium plan → style at premium materials.
Never use marble in Economy. Never use basic ceramic in Premium (unless minimal style).

CRITICAL OUTPUT RULES:
- Your ENTIRE response must be a single valid JSON object.
- Start your response with { and end with }.
- No text before {. No text after }. No markdown. No code fences. No explanation.
- All prices must be realistic Egyptian market prices in EGP.
- Material quantities must be calculated from the actual room dimensions provided.
- Always include a 10% waste factor on area-based materials.

Return this exact JSON structure — fill ALL fields for all 3 plans:

{
  "room_analysis": {
    "room_type": "bedroom | living_room | kitchen | bathroom | office | other",
    "detected_features": ["window", "door", "bare brick", "balcony door"],
    "wall_condition": "bare brick | rough plaster | smooth plaster | painted",
    "estimated_ceiling_height_m": 2.8,
    "special_notes": "any important observations"
  },
  "finishing_plans": [
    {
      "plan_name": "Economy",
      "style": "Simple modern",
      "description": "One sentence describing this finish level",
      "total_cost_egp": 35000,
      "materials_subtotal_egp": 22000,
      "labor_subtotal_egp": 13000,
      "materials": [
        {
          "category": "flooring | walls | ceiling | doors | windows | electrical | plumbing | painting | other",
          "name": "exact product name",
          "quantity": 22.0,
          "unit": "m2 | m | piece | kg | liter | box",
          "unit_price_egp": 175,
          "total_egp": 3850,
          "notes": "include waste factor or brand suggestions"
        }
      ],
      "labor": [
        {
          "trade": "Tiler | Painter | Carpenter | Electrician | Plumber | Plasterer | General Labor",
          "description": "what this worker does",
          "days": 3,
          "daily_rate_egp": 700,
          "total_egp": 2100
        }
      ],
      "timeline_days": 14
    },
    {
      "plan_name": "Standard",
      "style": "Contemporary",
      "description": "",
      "total_cost_egp": 65000,
      "materials_subtotal_egp": 42000,
      "labor_subtotal_egp": 23000,
      "materials": [],
      "labor": [],
      "timeline_days": 20
    },
    {
      "plan_name": "Premium",
      "style": "Luxury modern",
      "description": "",
      "total_cost_egp": 120000,
      "materials_subtotal_egp": 80000,
      "labor_subtotal_egp": 40000,
      "materials": [],
      "labor": [],
      "timeline_days": 30
    }
  ],
  "recommended_plan": "Standard",
  "recommendation_reason": "One sentence explaining why this plan suits this room and budget"
}
"""


def analyze_room(
    image_bytes: bytes,
    length_m: float,
    width_m: float,
    height_m: float,
    budget_egp: int,
    style_preference: str = "modern"
) -> dict:
    """Send room image + dimensions to Gemini Vision and return parsed JSON plan."""

    floor_area = round(length_m * width_m, 2)
    wall_area  = round(2 * (length_m + width_m) * height_m, 2)

    user_prompt = f"""
Analyze this room image and provide a complete finishing plan.

ROOM MEASUREMENTS:
- Length:     {length_m} m
- Width:      {width_m} m
- Height:     {height_m} m
- Floor area: {floor_area} m²
- Wall area:  {wall_area} m²

USER PREFERENCES:
- Total budget: EGP {budget_egp:,}
- Preferred style: {style_preference}

Provide all 3 plans fully completed. Calculate all material quantities
from the exact measurements above. Use 2024-2025 Egyptian market prices in EGP.
"""

    response = _generate_with_fallback(image_bytes, user_prompt, SYSTEM_PROMPT)

    raw_text = response.text.strip()

    # Strip markdown fences if Gemini adds them
    clean = raw_text
    if clean.startswith("```"):
        parts = clean.split("```")
        clean = parts[1].lstrip("json").strip() if len(parts) > 1 else clean[3:]
    clean = clean.strip()

    return json.loads(clean)
