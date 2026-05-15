import base64
import json
import os
from dotenv import load_dotenv
from groq import Groq

load_dotenv()
_client = Groq(api_key=os.getenv("GROQ_API_KEY"))

MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"


# ─────────────────────────────────────────────
# SYSTEM PROMPT — tune this for better results
# ─────────────────────────────────────────────
SYSTEM_PROMPT = """
You are an expert Egyptian interior designer and construction cost estimator.
You have deep knowledge of Egyptian building material prices in EGP as of 2024-2025,
specifically for Cairo and Giza markets (vendors like Ceramica Cleopatra, Al-Mansour,
Delta Paints, El-Nasr Tiles, and local labor rates).

When given a room photo and its dimensions, analyze the room carefully and produce
a complete, realistic finishing plan with 3 cost tiers.

CRITICAL OUTPUT RULES:
- Your ENTIRE response must be a single valid JSON object.
- Start your response with { and end with }.
- No text before {. No text after }. No markdown. No code fences. No explanation.
- All prices must be realistic Egyptian market prices in EGP (not USD).
- Material quantities must be calculated from the actual room dimensions provided.
- Always include a 10% waste factor on all area-based materials (tiles, paint, etc.).

Required JSON structure — fill ALL fields completely for all 3 plans:

{
  "room_analysis": {
    "room_type": "bedroom | living_room | kitchen | bathroom | office | other",
    "detected_features": ["list of visible features: window, door, balcony door, bare brick, plastered walls, etc."],
    "wall_condition": "bare brick | rough plaster | smooth plaster | painted",
    "estimated_ceiling_height_m": 2.8,
    "special_notes": "any important observations about the room"
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
          "notes": "include waste factor info or brand suggestions"
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
      "description": "...",
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
      "description": "...",
      "total_cost_egp": 120000,
      "materials_subtotal_egp": 80000,
      "labor_subtotal_egp": 40000,
      "materials": [],
      "labor": [],
      "timeline_days": 30
    }
  ],
  "recommended_plan": "Standard",
  "recommendation_reason": "Explain in one sentence why this plan is recommended for this room and budget"
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
    """
    Send the room image + dimensions to Groq Vision and return the parsed JSON plan.
    """

    floor_area = round(length_m * width_m, 2)
    wall_area = round(2 * (length_m + width_m) * height_m, 2)

    user_prompt = f"""
Analyze this room image and provide a complete finishing plan.

ROOM MEASUREMENTS:
- Length:     {length_m} m
- Width:      {width_m} m
- Height:     {height_m} m
- Floor area: {floor_area} m²
- Wall area:  {wall_area} m² (all 4 walls, before subtracting openings)

USER PREFERENCES:
- Total budget: EGP {budget_egp:,}
- Preferred style: {style_preference}

INSTRUCTIONS:
- Provide all 3 plans (Economy, Standard, Premium) fully completed.
- Calculate all material quantities from the exact measurements above.
- Use realistic 2024-2025 Egyptian market prices in EGP.
- Include every trade needed: plastering, tiling, painting, electrical rough-in, etc.
- The Economy plan should fit within or near the stated budget if possible.
"""

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    response = _client.chat.completions.create(
        model=MODEL,
        messages=[
            {
                "role": "system",
                "content": SYSTEM_PROMPT,
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                    },
                    {
                        "type": "text",
                        "text": user_prompt,
                    },
                ],
            },
        ],
        max_tokens=4096,
        temperature=0.2,
    )

    raw_text = response.choices[0].message.content.strip()

    # Strip markdown code fences if model adds them
    clean = raw_text
    if clean.startswith("```"):
        clean = clean.split("```")[-2] if "```" in clean[3:] else clean[3:]
        clean = clean.lstrip("json").strip()
    clean = clean.strip()

    return json.loads(clean)
