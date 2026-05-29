import os
import io
import base64
import torch
from PIL import Image

# ---------------------------------------------------------------------------
# Model selection — set SD_MODEL env var to switch:
#   sd15        → runwayml/stable-diffusion-v1-5  (default, CPU-safe, 4 GB VRAM)
#   sdxl        → stabilityai/stable-diffusion-xl-base-1.0 (8-12 GB VRAM)
#   sdxl-turbo  → stabilityai/sdxl-turbo (8 GB VRAM, 1-4 steps, fastest)
# ---------------------------------------------------------------------------
SD_MODEL_CHOICE = os.getenv("SD_MODEL", "sd15").lower()

USE_GPU = torch.cuda.is_available()
DTYPE   = torch.float16 if USE_GPU else torch.float32

_DEFAULT_STEPS   = 30 if USE_GPU else 15
_DEFAULT_WIDTH   = 768
_DEFAULT_HEIGHT  = 768   # now square (aspect preserved by preprocessing)

print(f"Loading Stable Diffusion [{SD_MODEL_CHOICE}] on {'GPU' if USE_GPU else 'CPU'}...")

if SD_MODEL_CHOICE == "sdxl-turbo":
    from diffusers import AutoPipelineForImage2Image
    pipe = AutoPipelineForImage2Image.from_pretrained(
        "stabilityai/sdxl-turbo",
        torch_dtype=DTYPE,
        variant="fp16" if USE_GPU else None,
    )
    _DEFAULT_STEPS  = 4      # SDXL-Turbo distillation: 1-4 steps sufficient
    _DEFAULT_WIDTH  = 512
    _DEFAULT_HEIGHT = 512
elif SD_MODEL_CHOICE == "sdxl":
    from diffusers import AutoPipelineForImage2Image
    pipe = AutoPipelineForImage2Image.from_pretrained(
        "stabilityai/stable-diffusion-xl-base-1.0",
        torch_dtype=DTYPE,
        variant="fp16" if USE_GPU else None,
    )
    _DEFAULT_WIDTH  = 1024
    _DEFAULT_HEIGHT = 1024
else:
    from diffusers import StableDiffusionImg2ImgPipeline
    pipe = StableDiffusionImg2ImgPipeline.from_pretrained(
        "runwayml/stable-diffusion-v1-5",
        torch_dtype=DTYPE,
        safety_checker=None,
        requires_safety_checker=False,
    )
    _DEFAULT_WIDTH  = 768
    _DEFAULT_HEIGHT = 768

if USE_GPU:
    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()
    print(f"GPU ready: {torch.cuda.get_device_name(0)}")
else:
    print("Warning: No GPU detected — using CPU. Images will be slow.")

print(f"Stable Diffusion [{SD_MODEL_CHOICE}] loaded.")


# ---------------------------------------------------------------------------
# Style taxonomy — maps user style → SD keyword sets + quality signals
# ---------------------------------------------------------------------------
STYLE_TAXONOMY = {
    "luxury": {
        "sd_keywords": [
            "luxury interior design", "premium marble flooring", "designer furniture",
            "crystal chandelier", "gilded accents", "coffered ceiling", "velvet upholstery",
            "Italian marble", "gold fixtures", "floor-to-ceiling curtains",
            "bespoke millwork", "ornate moldings", "luxury villa interior",
            "high-end Egyptian interior design", "opulent finish",
        ],
        "negative_additions": [
            "basic furniture", "plain walls", "simple flooring", "budget materials",
            "IKEA furniture", "laminate flooring", "exposed pipes",
        ],
        "color_palette": "gold, cream, deep jewel tones",
        "ceiling_type": "coffered, gypsum ornate, chandelier focal point",
    },
    "modern": {
        "sd_keywords": [
            "modern interior design", "contemporary furniture", "clean lines",
            "neutral color palette", "minimalist modern", "concrete and wood accents",
            "recessed lighting", "open plan", "sleek finishes", "Scandinavian influence",
            "modern Egyptian apartment",
        ],
        "negative_additions": [
            "ornate decoration", "baroque", "traditional patterns", "heavy curtains",
            "antique furniture", "dark wood",
        ],
        "color_palette": "white, grey, warm wood tones",
        "ceiling_type": "flat, recessed lighting, cove lighting",
    },
    "classic": {
        "sd_keywords": [
            "classic interior design", "traditional Egyptian style", "ornate crown molding",
            "rich wood furniture", "Persian rug", "warm amber lighting",
            "wainscoting", "decorative ceiling medallion", "damask patterns",
            "traditional Arabic interior", "antique-inspired furniture",
            "classic Egyptian living room",
        ],
        "negative_additions": [
            "minimalist", "industrial", "concrete", "metal furniture", "plain walls",
        ],
        "color_palette": "burgundy, gold, cream, dark wood",
        "ceiling_type": "decorative plaster, medallion, crown molding",
    },
    "minimal": {
        "sd_keywords": [
            "minimalist interior design", "Japandi style", "uncluttered space",
            "functional furniture only", "negative space", "monochromatic palette",
            "natural materials", "simple forms", "quiet luxury", "calm and serene interior",
        ],
        "negative_additions": [
            "decorative objects", "busy patterns", "clutter", "ornate details",
            "heavy furniture", "bright colors", "multiple rugs",
        ],
        "color_palette": "white, off-white, light grey, natural wood",
        "ceiling_type": "plain flat, indirect lighting only",
    },
    "minimalist": {  # alias
        "sd_keywords": [
            "minimalist interior design", "Japandi style", "uncluttered space",
            "functional furniture only", "negative space", "monochromatic palette",
            "natural materials", "simple forms", "quiet luxury",
        ],
        "negative_additions": [
            "decorative objects", "busy patterns", "clutter", "ornate details",
            "heavy furniture", "bright colors",
        ],
        "color_palette": "white, off-white, light grey, natural wood",
        "ceiling_type": "plain flat, indirect lighting only",
    },
}

# Fallback when user passes an unknown style string
_DEFAULT_STYLE_DATA = STYLE_TAXONOMY["modern"]


# ---------------------------------------------------------------------------
# Budget tiers — EGP per m² drives visual quality signals in SD
# ---------------------------------------------------------------------------
BUDGET_TIERS = {
    "ultra_economy": {
        "range": (0, 1500),
        "sd_terms": ["economy finish", "basic ceramic tiles", "standard paint", "simple furniture"],
        "materials_hint": "basic ceramic floor, emulsion paint, gypsum board ceiling",
    },
    "economy": {
        "range": (1500, 4000),
        "sd_terms": ["affordable modern finish", "porcelain tiles", "semi-gloss paint"],
        "materials_hint": "porcelain tiles, washable paint, suspended ceiling",
    },
    "standard": {
        "range": (4000, 9000),
        "sd_terms": ["contemporary finish", "quality porcelain", "textured wall paint", "elegant furniture"],
        "materials_hint": "large format tiles, textured paint, gypsum ceiling with cove",
    },
    "premium": {
        "range": (9000, 20000),
        "sd_terms": ["premium interior", "imported marble look tiles", "designer furniture", "statement lighting"],
        "materials_hint": "large format porcelain, venetian plaster, ornate gypsum ceiling",
    },
    "luxury": {
        "range": (20000, float("inf")),
        "sd_terms": [
            "luxury interior", "Italian Carrara marble", "crystal chandelier",
            "bespoke furniture", "premium velvet", "gold fixtures", "marble walls",
        ],
        "materials_hint": "Italian marble, Venetian plaster walls, coffered gypsum ceiling",
    },
}


# ---------------------------------------------------------------------------
# Room-type base prompts — prevent cross-contamination (bed in kitchen, etc.)
# ---------------------------------------------------------------------------
ROOM_TYPE_PROMPTS = {
    "bedroom": {
        "base": "bedroom interior, bed with headboard, bedside tables, wardrobe",
        "negative": "sofa, dining table, kitchen appliances, toilet",
    },
    "living_room": {
        "base": "living room interior, sofa set, coffee table, TV unit, entertainment area",
        "negative": "bed, toilet, kitchen stove, dining table in main view",
    },
    "kitchen": {
        "base": "modern kitchen interior, kitchen cabinets, countertop, backsplash",
        "negative": "bed, sofa, toilet",
    },
    "bathroom": {
        "base": "bathroom interior, bathtub or shower cabin, vanity unit, bathroom mirror, tiles",
        "negative": "sofa, bed, kitchen appliances",
    },
    "dining_room": {
        "base": "dining room interior, dining table, dining chairs, buffet cabinet, pendant light over table",
        "negative": "bed, sofa, kitchen appliances",
    },
    "reception": {
        "base": "formal reception room, formal seating arrangement, console table, decorative elements, chandelier",
        "negative": "bed, kitchen, toilet",
    },
    "kids_room": {
        "base": "children's bedroom, kids bed, study desk, toy storage, playful colors",
        "negative": "adult furniture, dark palette, formal styling",
    },
    "office": {
        "base": "home office interior, executive desk, ergonomic chair, bookshelf, professional atmosphere",
        "negative": "bed, kitchen, casual furniture",
    },
}

_DEFAULT_ROOM_DATA = {
    "base": "professionally finished room interior",
    "negative": "",
}

# ---------------------------------------------------------------------------
# Material-name fragment → SD prompt term mapping
# ---------------------------------------------------------------------------
MATERIAL_TO_PROMPT = {
    "marble":           "polished marble floor",
    "porcelain":        "large format porcelain floor tiles",
    "ceramic":          "ceramic floor tiles",
    "hardwood":         "solid hardwood parquet floor",
    "engineered wood":  "engineered wood flooring",
    "granite":          "granite floor tiles",
    "travertine":       "travertine stone floor",
    "venetian plaster": "Venetian plaster walls",
    "textured paint":   "textured wall finish",
    "emulsion paint":   "smooth painted walls",
    "wallpaper":        "decorative wallpaper",
    "wall tiles":       "wall tiles",
    "gypsum board":     "suspended gypsum board ceiling",
    "coffered":         "coffered ceiling with moldings",
    "cove lighting":    "cove-lit ceiling",
    "chandelier":       "chandelier focal point",
    "crystal":          "crystal chandelier",
    "velvet":           "premium velvet upholstery",
    "gold":             "gold hardware accents",
    "brass":            "brass fixture accents",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def budget_to_tier(budget_egp: int, floor_area_m2: float) -> str:
    """Classify budget into a quality tier based on EGP per m²."""
    per_m2 = budget_egp / max(floor_area_m2, 1.0)
    for tier_name, tier in BUDGET_TIERS.items():
        lo, hi = tier["range"]
        if lo <= per_m2 < hi:
            return tier_name
    return "luxury"


def style_to_strength(user_style: str) -> float:
    """
    SD img2img denoising strength per style.
    Higher → more transformation (luxury needs marble/ceiling replacement).
    Lower → preserve room structure (minimal just cleans up existing layout).
    """
    return {
        "luxury":     0.75,
        "classic":    0.70,
        "modern":     0.65,
        "minimal":    0.55,
        "minimalist": 0.55,
    }.get(user_style.lower(), 0.65)


def budget_to_guidance_scale(budget_tier: str) -> float:
    """
    Higher budget tier → more prompt-adherent generation → higher guidance scale.
    SDXL-Turbo ignores this (uses 0.0).
    """
    if SD_MODEL_CHOICE == "sdxl-turbo":
        return 0.0
    return {
        "ultra_economy": 6.0,
        "economy":       6.5,
        "standard":      7.5,
        "premium":       8.0,
        "luxury":        9.0,
    }.get(budget_tier, 7.5)


# ---------------------------------------------------------------------------
# Core prompt builder v2
# Returns (prompt, negative_prompt) — both informed by style + budget + materials
# ---------------------------------------------------------------------------

def build_prompt_v2(
    room_type: str,
    user_style: str,
    budget_egp: int,
    floor_area_m2: float,
    materials: list,
) -> tuple:
    """
    Build SD prompt from all available context.
    All four axes (style, budget, materials, room type) now reach the model.
    """
    style = user_style.lower().strip()
    style_data = STYLE_TAXONOMY.get(style, _DEFAULT_STYLE_DATA)

    tier      = budget_to_tier(budget_egp, floor_area_m2)
    tier_data = BUDGET_TIERS[tier]

    room_key  = room_type.lower().replace(" ", "_")
    room_data = ROOM_TYPE_PROMPTS.get(room_key, _DEFAULT_ROOM_DATA)

    # Extract all recognisable material terms from the plan
    mat_prompts = []
    for m in materials:
        name_lower = m.get("name", "").lower()
        for keyword, term in MATERIAL_TO_PROMPT.items():
            if keyword in name_lower:
                mat_prompts.append(term)
                break

    if not mat_prompts:
        mat_prompts = [tier_data["materials_hint"]]

    # Scale hint from floor area
    size_hint = ""
    if floor_area_m2 < 12:
        size_hint = "compact well-organised space, appropriately scaled furniture, "
    elif floor_area_m2 > 35:
        size_hint = "spacious open interior, generous furniture arrangement, "

    style_kws  = ", ".join(style_data["sd_keywords"][:5])
    budget_kws = ", ".join(tier_data["sd_terms"][:3])
    mat_kws    = ", ".join(mat_prompts[:4])

    prompt = (
        f"{room_data['base']}, "
        f"{style_kws}, "
        f"{budget_kws}, "
        f"{mat_kws}, "
        f"{size_hint}"
        f"bright natural lighting, photorealistic interior photography, "
        f"architectural visualization, Egyptian home interior, "
        f"high-end interior design magazine photo, sharp focus, 4K, HDR"
    )

    negative_base = (
        "bare concrete, unfinished walls, construction site, scaffolding, "
        "bare brick, unpainted, dark, blurry, low quality, ugly, deformed, dirty, "
        "people, watermark, text, signature, cartoon, animation, illustration, "
        "oversized furniture, impossible room layout, floating objects, "
        "wrong perspective, fish-eye lens distortion"
    )
    negative_style = ", ".join(style_data["negative_additions"])
    negative_room  = room_data.get("negative", "")

    negative_prompt = ", ".join(filter(None, [negative_base, negative_style, negative_room]))

    return prompt, negative_prompt


# ---------------------------------------------------------------------------
# Legacy prompt builder — kept as fallback, not used in new pipeline
# ---------------------------------------------------------------------------

def build_prompt(room_analysis: dict, finishing_plan: dict) -> tuple:
    materials   = finishing_plan.get("materials", [])
    flooring = next(
        (m["name"] for m in materials if m["category"] == "flooring"),
        "ceramic floor tiles"
    )
    wall_finish = next(
        (m["name"] for m in materials if m["category"] in ["walls", "painting"]),
        "painted walls"
    )
    style = finishing_plan.get("style", "modern")
    room_type = room_analysis.get("room_type", "room")
    prompt = (
        f"professionally finished {room_type} interior, {style} interior design, "
        f"{flooring}, {wall_finish}, bright natural lighting, clean and elegant, "
        f"high quality interior photography, photorealistic, architectural visualization render, "
        f"Egyptian home, interior design magazine photo, sharp focus, 4K"
    )
    negative_prompt = (
        "bare brick, unfinished, construction site, scaffolding, "
        "dark, blurry, low quality, ugly, deformed, dirty, "
        "people, watermark, text, signature, cartoon, illustration"
    )
    return prompt, negative_prompt


# ---------------------------------------------------------------------------
# Main generation function
# ---------------------------------------------------------------------------

def generate_finished_room(
    room_image_bytes: bytes,
    room_analysis: dict,
    finishing_plan: dict,
    user_style: str = "modern",
    budget_egp: int = 50000,
    floor_area_m2: float = 16.0,
    strength: float = None,
    steps: int = _DEFAULT_STEPS,
) -> tuple:
    """
    Transform an empty room photo into a finished room render.

    Returns (base64_jpeg_string, prompt_used) so the caller can build
    a consistency envelope.

    strength: if None, derived from user_style via style_to_strength().
    """
    if strength is None:
        strength = style_to_strength(user_style)

    room_type  = room_analysis.get("room_type", "room")
    materials  = finishing_plan.get("materials", [])

    prompt, negative_prompt = build_prompt_v2(
        room_type=room_type,
        user_style=user_style,
        budget_egp=budget_egp,
        floor_area_m2=floor_area_m2,
        materials=materials,
    )

    tier            = budget_to_tier(budget_egp, floor_area_m2)
    guidance_scale  = budget_to_guidance_scale(tier)

    # Image is already aspect-preserved + padded by prepare_image_for_sd()
    image = Image.open(io.BytesIO(room_image_bytes)).convert("RGB")
    # Ensure correct target size for the loaded model
    if image.size != (_DEFAULT_WIDTH, _DEFAULT_HEIGHT):
        image = image.resize((_DEFAULT_WIDTH, _DEFAULT_HEIGHT), Image.LANCZOS)

    print(
        f"Generating room render — model={SD_MODEL_CHOICE}, "
        f"steps={steps}, strength={strength:.2f}, guidance={guidance_scale}, "
        f"style={user_style}, tier={tier}"
    )

    with torch.inference_mode():
        result = pipe(
            prompt=prompt,
            negative_prompt=negative_prompt,
            image=image,
            strength=strength,
            guidance_scale=guidance_scale,
            num_inference_steps=steps,
        ).images[0]

    buffer = io.BytesIO()
    result.save(buffer, format="JPEG", quality=90)
    b64 = base64.b64encode(buffer.getvalue()).decode("utf-8")

    if USE_GPU:
        vram_used = torch.cuda.max_memory_allocated() / 1024 ** 3
        print(f"Done. VRAM peak: {vram_used:.2f} GB")

    return b64, prompt
