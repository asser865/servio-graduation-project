from diffusers import StableDiffusionImg2ImgPipeline
import torch
from PIL import Image
import io
import base64

# Load model once at server startup
USE_GPU = torch.cuda.is_available()
DTYPE   = torch.float16 if USE_GPU else torch.float32

# CPU SD is ~3× slower per step and ~33% slower per pixel. Use fewer steps
# and a smaller resolution on CPU to keep total render time under ~25s.
# GPU keeps full quality (30 steps, 768×512).
_DEFAULT_STEPS = 30 if USE_GPU else 15
_DEFAULT_WIDTH  = 768 if USE_GPU else 512
_DEFAULT_HEIGHT = 512

print(f"Loading Stable Diffusion on {'GPU' if USE_GPU else 'CPU'}...")

pipe = StableDiffusionImg2ImgPipeline.from_pretrained(
    "runwayml/stable-diffusion-v1-5",
    torch_dtype=DTYPE,
    safety_checker=None,
    requires_safety_checker=False
)

if USE_GPU:
    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()
    print(f"GPU ready: {torch.cuda.get_device_name(0)}")
else:
    print("Warning: No GPU — using CPU. Images will be slow.")

print("Stable Diffusion model loaded.")


def build_prompt(room_analysis: dict, finishing_plan: dict) -> tuple:
    """Build detailed image generation prompt from Gemini finishing plan."""
    room_type   = room_analysis.get("room_type", "room")
    style       = finishing_plan.get("style", "modern")
    materials   = finishing_plan.get("materials", [])

    flooring = next(
        (m["name"] for m in materials if m["category"] == "flooring"),
        "ceramic floor tiles"
    )
    wall_finish = next(
        (m["name"] for m in materials if m["category"] in ["walls", "painting"]),
        "painted walls"
    )

    prompt = (
        f"professionally finished {room_type} interior, "
        f"{style} interior design, "
        f"{flooring}, {wall_finish}, "
        f"bright natural lighting, clean and elegant, "
        f"high quality interior photography, photorealistic, "
        f"architectural visualization render, Egyptian home, "
        f"interior design magazine photo, sharp focus, 4K"
    )

    negative_prompt = (
        "bare brick, unfinished, construction site, scaffolding, "
        "dark, blurry, low quality, ugly, deformed, dirty, "
        "people, watermark, text, signature, cartoon, illustration"
    )

    return prompt, negative_prompt


def generate_finished_room(
    room_image_bytes: bytes,
    room_analysis: dict,
    finishing_plan: dict,
    strength: float = 0.65,
    steps: int = _DEFAULT_STEPS
) -> str:
    """
    Transform empty room photo into a finished room render.
    Returns base64-encoded JPEG string.

    strength: 0.5 = keeps original layout | 0.65 = recommended | 0.8 = heavy transformation
    steps:    20 = fast testing | 30 = recommended | 50 = best quality
    """
    image = Image.open(io.BytesIO(room_image_bytes)).convert("RGB")
    image = image.resize((_DEFAULT_WIDTH, _DEFAULT_HEIGHT))

    prompt, negative_prompt = build_prompt(room_analysis, finishing_plan)

    print(f"Generating room render — {steps} steps, strength={strength}")

    with torch.inference_mode():
        result = pipe(
            prompt=prompt,
            negative_prompt=negative_prompt,
            image=image,
            strength=strength,
            guidance_scale=7.5,
            num_inference_steps=steps,
        ).images[0]

    buffer = io.BytesIO()
    result.save(buffer, format="JPEG", quality=90)
    b64 = base64.b64encode(buffer.getvalue()).decode("utf-8")

    if USE_GPU:
        vram_used = torch.cuda.max_memory_allocated() / 1024**3
        print(f"Done. VRAM used: {vram_used:.2f} GB")

    return b64
