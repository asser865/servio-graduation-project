import json
import os
import re
from typing import Any, Dict, List, Optional, Tuple

from dotenv import load_dotenv
from fastapi import FastAPI
from groq import Groq
from pydantic import BaseModel

load_dotenv()

ALLOWED_SERVICES = [
    "Plumbing",
    "Electrical",
    "A/C",
    "Carpentry",
    "Cleaning",
    "Painting",
    "Appliance Repair",
    "Handyman",
]

SERVICE_ALIASES = {
    "plumbing": "Plumbing",
    "plumber": "Plumbing",
    "electrical": "Electrical",
    "electrician": "Electrical",
    "electricity": "Electrical",
    "a/c": "A/C",
    "ac": "A/C",
    "air conditioning": "A/C",
    "air conditioner": "A/C",
    "hvac": "A/C",
    "carpentry": "Carpentry",
    "carpenter": "Carpentry",
    "cleaning": "Cleaning",
    "cleaner": "Cleaning",
    "painting": "Painting",
    "painter": "Painting",
    "appliance repair": "Appliance Repair",
    "appliance": "Appliance Repair",
    "handyman": "Handyman",
}

URGENCY_LABELS = {
    "urgent": "Book First",
    "same_day": "Same Day",
    "high": "This Week",
    "low": "Can Wait",
}

MISSING_FIELD_LABELS = {
    "location": "Location (neighbourhood or city)",
    "budget": "Budget (EGP amount or range)",
    "time_range": "Time or urgency",
    "problem_details": "A clearer description of the problem",
}

SERVICE_PRIORITY = {
    "Electrical": 100,
    "Plumbing": 90,
    "Appliance Repair": 75,
    "A/C": 65,
    "Carpentry": 40,
    "Handyman": 35,
    "Cleaning": 30,
    "Painting": 20,
}

SERVICE_PATTERNS = {
    "Plumbing": [
        r"\bplumb(?:er|ing)?\b",
        r"\bsink\b",
        r"\btoilet\b",
        r"\bdrain(?:s|ed|ing)?\b",
        r"\bpipe(?:s)?\b",
        r"\bfaucet\b",
        r"\bshower\b",
        r"\bwater heater\b",
        r"\bblocked pipe(?:s)?\b",
        r"\bleak\b",
        r"\bleakage\b",
        r"\bmold(?:y)?\b",
        r"\bmould(?:y)?\b",
        r"\bdamp(?:ness)?\b",
        r"\bwater\s+stain(?:s)?\b",
        r"\bbrown\s+stain(?:s)?\b",
        r"\bstain(?:s)?\s+(?:spread|grow|expand)\w*\b",
        r"\bseep(?:ing|age)?\b",
        r"\bhot\s+water\b",
        r"\bno\s+(?:hot|warm)\s+water\b",
        r"\bboiler\b",
        r"سباك",
        r"سباكة",
        r"حوض",
        r"تواليت",
        r"مرحاض",
        r"صرف",
        r"بالوعة",
        r"ماسورة",
        r"مواسير",
        r"مياه",
        r"مية",
        r"تسريب",
    ],
    "Electrical": [
        r"\belectric(?:al|ian|ity)\b",
        r"\blights?\b",
        r"\bsocket\b",
        r"\boutlet\b",
        r"\bpanel\b",
        r"\bfuse box\b",
        r"\bbreaker\b",
        r"\bcircuit breaker\b",
        r"\bwiring\b",
        r"\bwire(?:s)?\b",
        r"\bflicker(?:ing)?\b",
        r"\bsparks?\b",
        r"كهرب",
        r"بريزة",
        r"مقبس",
        r"سوكت",
        r"لوحة كهرب",
        r"قاطع",
        r"أسلاك",
        r"اسلاك",
        r"شرر",
        r"الانارة",
        r"الإنارة",
        r"الأنوار",
    ],
    "A/C": [
        r"\ba/c\b",
        r"\bac\b",
        r"\bair conditioner\b",
        r"\bair conditioning\b",
        r"\bhvac\b",
        r"\bthermostat\b",
        r"تكييف",
        r"تكيف",
        r"مكيف",
    ],
    "Carpentry": [
        r"\bcarpent(?:er|ry)\b",
        r"\bdoor\b",
        r"\bcabinet\b",
        r"\bwooden cabinet\b",
        r"\bshelf(?:s)?\b",
        r"\bwardrobe\b",
        r"\bwindow frame\b",
        r"\bwooden\b",
        r"نجار",
        r"نجارة",
        r"باب",
        r"دولاب",
        r"خزانة",
        r"(?<![\u0600-\u06FF])رف(?![\u0600-\u06FF])",
        r"(?<![\u0600-\u06FF])أرفف(?![\u0600-\u06FF])",
        r"(?<![\u0600-\u06FF])ارفف(?![\u0600-\u06FF])",
        r"خشب",
    ],
    "Cleaning": [
        r"\bclean(?:ing|er)?\b",
        r"\bdeep cleaning\b",
        r"\bmaid\b",
        r"\bhousekeeping\b",
        r"\bcarpet cleaning\b",
        r"\bsofa cleaning\b",
        r"تنظيف",
        r"نظافة",
        r"عامل[ة]?\s+نظافة",
        r"clean my house",
    ],
    "Painting": [
        r"\bpaint(?:ing|ed)?\b",
        r"\brepaint\b",
        r"\bwall paint\b",
        r"\bpaint\s+(?:is\s+)?bubbling\b",
        r"\bbubbling\s+(?:paint|walls?)\b",
        r"\bpaint\s+(?:is\s+)?peeling\b",
        r"\bpeeling\s+(?:paint|walls?)\b",
        r"\bpaint\s+(?:coming|falling)\s+off\b",
        r"\bwall(?:s)?\s+(?:is\s+|are\s+)?bubbling\b",
        r"\bwall(?:s)?\s+(?:is\s+|are\s+)?peeling\b",
        r"\bwater\s+damage(?:d)?\s+(?:paint|wall|walls)\b",
        r"\bmoisture\s+damage(?:d)?\s+(?:paint|wall|walls)\b",
        r"دهان",
        r"بوية",
        r"طلاء",
    ],
    "Appliance Repair": [
        r"\bappliance\b",
        r"\bwashing machine\b",
        r"\bwasher\b",
        r"\bfridge\b",
        r"\brefrigerator\b",
        r"\boven\b",
        r"\bmicrowave\b",
        r"\bdishwasher\b",
        r"\bstove\b",
        r"\bdryer\b",
        r"غسالة",
        r"ثلاجة",
        r"فرن",
        r"ميكروويف",
        r"ميكرويف",
        r"غسالة أطباق",
        r"غسالة اطباق",
        r"بوتاجاز",
    ],
    "Handyman": [
        r"\bhandyman\b",
        r"\btv mount(?:ed|ing)?\b",
        r"\bmount(?:ing)?\b.*\b(tv|mirror|picture)\b",
        r"\bhang(?:ing)?\b.*\b(picture|mirror)\b",
        r"\bassemble(?:d|ing)? furniture\b",
        r"\bsmall home repairs?\b",
        r"فني شامل",
        r"تركيب تلفزيون",
        r"تعليق مرآة",
        r"تعليق مراية",
        r"تعليق صورة",
        r"تجميع أثاث",
        r"تجميع اثاث",
    ],
}

ROOM_ONLY_LOCATION_TOKENS = {
    "bathroom",
    "toilet",
    "kitchen",
    "bedroom",
    "living room",
    "room",
    "hallway",
    "ceiling",
    "wall",
    "walls",
    "floor",
    "panel",
    "electrical panel",
    "breaker",
    "socket",
    "outlet",
}

PAINT_DAMAGE_PATTERNS = [
    re.compile(r"\bpaint\s+(?:is\s+)?(?:bubbling|peeling|cracking|coming\s+off|falling\s+off)\b", re.IGNORECASE),
    re.compile(r"\b(?:bubbling|peeling|cracking)\s+(?:paint|walls?)\b", re.IGNORECASE),
    re.compile(r"\bwall(?:s)?\s+(?:is\s+|are\s+)?(?:bubbling|peeling|cracking)\b", re.IGNORECASE),
    re.compile(r"\b(?:water|moisture)\s+damage(?:d)?\s+(?:paint|wall|walls)\b", re.IGNORECASE),
]

ACTIVE_LEAK_PATTERNS = [
    re.compile(r"\b(?:water|leak|leaking|drip|dripping|pipe|ceiling leak)\b", re.IGNORECASE),
    re.compile(r"(مياه|مية|تسريب|بتنقط|تنقيط)", re.IGNORECASE),
]

PREFERENCE_PATTERNS = [
    r"\bmy top priority is\s+{pattern}",
    r"\b{pattern}\s+matters more to me\b",
    r"\b{pattern}\s+is more important\b",
    r"\bfocus on\s+{pattern}\b",
    r"\bstart with\s+{pattern}\b",
    r"\b{pattern}\s+first\b",
    r"\bpriori(?:tize|tise)\s+{pattern}\b",
]

WATER_ON_ELECTRICAL_PATTERNS = [
    re.compile(
        r"(water|leak|leaking|drip|dripping|liquid).{0,40}"
        r"(on|onto|touching|into|near|over).{0,30}"
        r"(socket|outlet|panel|fuse box|breaker|circuit breaker|wiring|wire|electrical panel)",
        re.IGNORECASE,
    ),
    re.compile(
        r"(socket|outlet|panel|fuse box|breaker|circuit breaker|wiring|wire|electrical panel).{0,40}"
        r"(wet|water|leak|drip|dripping|liquid)",
        re.IGNORECASE,
    ),
    re.compile(
        r"(faucet|tap|pipe|sink|shower|hose).{0,40}"
        r"(electricity|electric|shock|electr\w+|spark|sparks|sparking)",
        re.IGNORECASE,
    ),
    re.compile(
        r"(electricity|electric|shock|electr\w+|spark|sparks|sparking).{0,40}"
        r"(faucet|tap|pipe|sink|shower|hose)",
        re.IGNORECASE,
    ),
    re.compile(
        r"(مياه|مية|تسريب|تسريب مياه|بتنقط|تنقيط|سائل).{0,40}"
        r"(على|فوق|جنب|قرب|لامس|واصل).{0,30}"
        r"(البريزة|المقبس|السوكت|اللوحة الكهربائية|لوحة الكهرباء|القاطع"
        r"|الاسلاك|الأسلاك|الانارة|الإنارة|الأنوار|الانوار|اللمبة|اللمب|النور)",
        re.IGNORECASE,
    ),
    re.compile(
        r"(البريزة|المقبس|السوكت|اللوحة الكهربائية|لوحة الكهرباء|القاطع"
        r"|الاسلاك|الأسلاك|الانارة|الإنارة|الأنوار|الانوار|اللمبة|اللمب|النور).{0,40}"
        r"(مياه|مية|تسريب|بتنقط|تنقيط|سائل)",
        re.IGNORECASE,
    ),
]

SYSTEM_PROMPT = """
You are a home services advisor for an Egyptian home services app called Servio.

Analyze the user's request in English or Arabic and return a JSON object only.
Never invent facts that are not grounded in the prompt. If data is missing, return null.

Return this exact shape:
{
  "service": "one of the 8 allowed services, or null if none apply",
  "confidence": 0-100,
  "location": "city or area mentioned, or null",
  "budget": "budget or price mentioned, or null",
  "time_range": "time or urgency mentioned, or null",
  "top_3": [
    {"service": "Plumbing", "confidence": 90},
    {"service": "Electrical", "confidence": 7},
    {"service": "Handyman", "confidence": 3}
  ],
  "steps": [
    {"step": 1, "service": "Electrical", "urgency": "urgent", "urgency_label": "Book First"}
  ],
  "advisor_message": "short grounded message"
}

Allowed services:
Plumbing, Electrical, A/C, Carpentry, Cleaning, Painting, Appliance Repair, Handyman

Core rules:
- "service" must be the single most urgent service, or null if no home service is described.
- "confidence" must be 0 if "service" is null.
- "top_3" must use only the allowed services.
- "steps" must include only services the user explicitly mentioned, or an undeniable direct dependency.
- If the user mentions only one problem, return exactly one step with urgency "urgent".
- Only one step may be "urgent".
- Use these urgency values only: "urgent", "same_day", "high", "low".
- Never add extra services just because they might be related.
- Keep the response grounded. When uncertain, lower confidence and keep missing fields null.

WHEN TO RETURN null service AND confidence 0:
- The request mentions no home service at all (food delivery, websites, pets, transport, health).
- The request is too generic to identify ANY service: "fix everything", "I need help",
  "something is broken", "help me", "I have a problem".
- Mentions of furniture scratching, biting, or damage BY a pet do NOT imply Handyman.
- Digital or IT work (websites, apps, computers) is not a home service.
- Return null even if you think you could guess — when in doubt, return null, confidence 0.

CRITICAL DISAMBIGUATION — appliances vs electrical:
- Sparks, burning smell, or smoke FROM an oven, stove, fridge, microwave, washing machine,
  dryer, or dishwasher = Appliance Repair. NOT Electrical.
- Electrical applies only when sparks or burning come from a wall socket, outlet, wiring,
  circuit breaker, fuse box, or electrical panel — not from an appliance.

CRITICAL DISAMBIGUATION — hidden water leaks vs cleaning:
- Mold, mildew, damp patches, brown stains, or water stains on walls or ceiling = Plumbing
  (hidden water leak). NOT Cleaning and NOT Painting unless user explicitly requests those.
- Cleaning is only when the user explicitly asks for cleaning ("clean my apartment", "maid service").
- Painting is only when the user explicitly asks for painting or describes cosmetic wall damage
  after the leak is already fixed.

SERVICE CLASSIFICATION GUIDE:
- Plumbing: water leaks, pipe problems, toilet issues, blocked drain, no hot water,
  mold on walls, damp patches, water stains
- Electrical: power outage, sparks from sockets/wiring/panel, circuit breaker, wiring,
  flickering lights
- A/C: air conditioner not cooling, AC broken, AC installation, thermostat, AC noise
- Carpentry: door/cabinet/wooden furniture broken, shelves, wardrobe, window frame
- Cleaning: dirty apartment, maid service, deep cleaning, carpet/sofa cleaning — only when
  explicitly requested
- Painting: painting walls, repaint room, paint peeling — only when explicitly requested
  or cosmetic damage after leak is fixed
- Appliance Repair: washing machine, fridge, oven, microwave, dishwasher, stove,
  boiler/water heater broken
- Handyman: TV mounting, hanging pictures/mirrors, assembling furniture, small repairs —
  only when explicitly requested

SAFETY RULE — water on electrical hardware:
Apply when the user says water or liquid is touching or dripping onto a socket, outlet,
panel, fuse box, breaker, or wiring — OR when a plumbing fixture (faucet, pipe, sink,
shower) is described together with electricity, electric shock, or sparks.
In that case: Electrical = urgent, Plumbing = same_day follow-up.
Return scenario "multi" with both services in steps.

Examples that MUST trigger multi (Electrical + Plumbing):
- "my faucet is leaking electricity" → faucet = plumbing + electricity = electrical hazard
- "the pipe near my socket is leaking" → plumbing + electrical contact
- "water from the sink is giving me electric shocks" → both
- "faucet sparks when I touch it" → both

Do NOT trigger the safety rule for:
- AC dripping water (condensation) or AC humidity
- Water inside an appliance (fridge pooling water, washer leaking internally)
- General plumbing leaks not touching electrical hardware
- Humidity or dampness in a room without contact with electrical components

Reply with JSON only. No markdown. No explanation.
"""

client = Groq(api_key=os.environ.get("GROQ_API_KEY"))
app = FastAPI(title="Servio AI Recommender API")


class PromptRequest(BaseModel):
    prompt: str


def _clean_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _is_room_only_location(value: Any) -> bool:
    text = _clean_text(value)
    if not text:
        return False
    normalized = re.sub(r"\b(my|the|a|an)\b", "", text.lower())
    normalized = re.sub(r"\s+", " ", normalized).strip(" -_,.")
    if normalized in ROOM_ONLY_LOCATION_TOKENS:
        return True
    words = [word for word in re.split(r"\s+", normalized) if word]
    return bool(words) and all(word in ROOM_ONLY_LOCATION_TOKENS for word in words)


def _sanitize_location(value: Any) -> Optional[str]:
    text = _clean_text(value)
    if not text or _is_room_only_location(text):
        return None
    return text


def _normalize_service(value: Any) -> Optional[str]:
    text = _clean_text(value)
    if not text:
        return None
    if text in ALLOWED_SERVICES:
        return text
    return SERVICE_ALIASES.get(text.lower())


def _normalize_confidence(value: Any) -> Optional[int]:
    if value is None:
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return max(0, min(100, int(round(number))))


def _extract_budget(prompt: str) -> Optional[str]:
    patterns = [
        r"\bbudget\s*(?:is|:)?\s*(\d+(?:\s*[-–]\s*\d+)?)\s*(EGP|LE)?\b",
        r"(\d+(?:\s*[-–]\s*\d+)?)\s*(EGP|LE)\b",
        r"الميزانية\s*(\d+(?:\s*[-–]\s*\d+)?)\s*جنيه",
        r"(\d+(?:\s*[-–]\s*\d+)?)\s*جنيه",
    ]
    for pattern in patterns:
        match = re.search(pattern, prompt, re.IGNORECASE)
        if not match:
            continue
        amount = match.group(1).strip()
        unit = match.group(2).strip() if match.lastindex and match.lastindex >= 2 and match.group(2) else None
        if "جنيه" in match.group(0):
            return f"{amount} جنيه"
        return f"{amount} {unit}" if unit else f"{amount} EGP"
    return None


def _extract_location(prompt: str) -> Optional[str]:
    candidates: List[str] = []

    for match in re.finditer(r"\bin\s+([^,.;]+)", prompt, re.IGNORECASE):
        candidates.append(match.group(1).strip())
    for match in re.finditer(r"\bفي\s+([^،,.]+)", prompt, re.IGNORECASE):
        candidates.append(match.group(1).strip())

    stop_patterns = [
        r"\bbudget\b.*$",
        r"\burgent\b.*$",
        r"\btoday\b.*$",
        r"\btomorrow\b.*$",
        r"\bweekend\b.*$",
        r"\bthis week\b.*$",
        r"\bnext week\b.*$",
        r"\bflexible\b.*$",
        r"\bASAP\b.*$",
        r"الميزانية.*$",
        r"عاجل.*$",
        r"النهارده.*$",
    ]

    for raw in reversed(candidates):
        cleaned = raw
        for stop_pattern in stop_patterns:
            cleaned = re.sub(stop_pattern, "", cleaned, flags=re.IGNORECASE).strip()
        cleaned = cleaned.strip(" -،,")
        cleaned = _sanitize_location(cleaned)
        if cleaned and len(cleaned) <= 60:
            return cleaned
    return None


def _extract_time_range(prompt: str) -> Optional[str]:
    patterns = [
        r"\basap\b",
        r"\burgent\b",
        r"\btoday\b",
        r"\btomorrow\b",
        r"\bthis weekend\b",
        r"\bweekend\b",
        r"\bthis week\b",
        r"\bnext week\b",
        r"\btonight\b",
        r"\bflexible\b",
        r"عاجل",
        r"النهارده",
        r"بكره",
        r"اليوم",
        r"هذا الأسبوع",
        r"نهاية الأسبوع",
    ]
    for pattern in patterns:
        match = re.search(pattern, prompt, re.IGNORECASE)
        if match:
            return match.group(0)
    return None


def _find_service_mentions(prompt: str) -> Dict[str, int]:
    mentions: Dict[str, int] = {}
    for service, patterns in SERVICE_PATTERNS.items():
        for pattern in patterns:
            match = re.search(pattern, prompt, re.IGNORECASE)
            if not match:
                continue
            current = mentions.get(service)
            if current is None or match.start() < current:
                mentions[service] = match.start()
    return mentions


def _rank_services_by_priority(mentions: Dict[str, int]) -> List[str]:
    return sorted(
        mentions,
        key=lambda service: (-SERVICE_PRIORITY.get(service, 0), mentions[service]),
    )


def _extract_explicit_services(prompt: str) -> List[str]:
    mentions = _find_service_mentions(prompt)
    return _rank_services_by_priority(mentions)


_APPLIANCE_WITH_SPARK = re.compile(
    r"\b(oven|stove|fridge|refrigerator|washing\s*machine|washer|dryer|"
    r"dishwasher|microwave|boiler)\b[^.!?\n]{0,60}"
    r"\b(spark|sparks|sparking|short\s*circuit|burning|smoke)\b"
    r"|"
    r"\b(spark|sparks|sparking|short\s*circuit|burning|smoke)\b[^.!?\n]{0,60}"
    r"\b(oven|stove|fridge|refrigerator|washing\s*machine|washer|dryer|"
    r"dishwasher|microwave|boiler)\b",
    re.IGNORECASE,
)


def _disambiguate_appliance_vs_electrical(
    prompt: str, services: List[str]
) -> List[str]:
    """Sparks/burning from a household appliance = Appliance Repair, not Electrical.

    This handles cases where a user describes sparks, smoke, burning, or a short
    circuit emanating from a named household appliance (oven, fridge, washer,
    boiler, etc.). In that case the booking should be Appliance Repair, not
    Electrical, because the fault is internal to the appliance.
    """
    if "Electrical" not in services or "Appliance Repair" not in services:
        return services
    if _APPLIANCE_WITH_SPARK.search(prompt):
        return [s for s in services if s != "Electrical"]
    return services


def _has_meaningful_text(prompt: str) -> bool:
    return bool(re.search(r"[A-Za-z\u0600-\u06FF]{2,}", prompt))


_HOME_CONTEXT_PATTERN = re.compile(
    r"\b(home|house|apartment|flat|room|kitchen|bathroom|bedroom|living room|"
    r"ceiling|wall|walls|floor|hallway|balcony|garage|garden|yard)\b"
    r"|(?<!\w)(بيت|شقة|منزل|غرفة|مطبخ|حمام|أوضة|اوضة|سقف|حائط|أرضية|بلكونة)(?!\w)",
    re.IGNORECASE,
)


def _has_home_context(prompt: str) -> bool:
    return bool(_HOME_CONTEXT_PATTERN.search(prompt))


def _build_no_service_result(
    extracted: Dict[str, Optional[str]],
    *,
    scenario: str,
    issue_mode: str,
    advisor_message: str,
    follow_up_message: str,
) -> Dict[str, Any]:
    return {
        "recommended_service": None,
        "confidence": 0,
        "extracted": extracted,
        "steps": [],
        "advisor_message": advisor_message,
        "top_3": [],
        "raw_prediction": None,
        "confidence_gate_triggered": True,
        "issue_mode": issue_mode,
        "needs_follow_up": True,
        "scenario": scenario,
        "missing_fields": ["problem_details"],
        "missing_field_labels": [MISSING_FIELD_LABELS["problem_details"]],
        "advisory_missing_fields": [],
        "advisory_missing_field_labels": [],
        "advisory_message_missing": "",
        "follow_up_message": follow_up_message,
        "service_options": [],
        "selected_service": None,
        "safety_risk": False,
        "safety_warning": None,
        "issues": [],
    }


def _build_unrecognized_result(_prompt: str, extracted: Dict[str, Optional[str]]) -> Dict[str, Any]:
    return _build_no_service_result(
        extracted,
        scenario="unrecognized",
        issue_mode="unrecognized",
        advisor_message=(
            "Tell us what home service issue you need help with, such as plumbing, electrical, A/C, "
            "cleaning, painting, carpentry, appliance repair, or handyman work."
        ),
        follow_up_message=(
            "Describe the home issue in a little more detail so Servio can identify the right service."
        ),
    )


def _build_vague_home_result(_prompt: str, extracted: Dict[str, Optional[str]]) -> Dict[str, Any]:
    return _build_no_service_result(
        extracted,
        scenario="vague",
        issue_mode="vague",
        advisor_message=(
            "We noticed you're looking for help at home. "
            "Please describe the specific issue (e.g. plumbing, electrical, A/C, cleaning, painting, "
            "carpentry, appliance repair, or handyman work)."
        ),
        follow_up_message=(
            "Could you describe what's wrong? For example: is it a leak, an electrical issue, or something else?"
        ),
    )


def _detect_user_selected_service(prompt: str, candidate_services: List[str]) -> Optional[str]:
    patterns_by_service = {
        service: [service] + SERVICE_PATTERNS.get(service, [])
        for service in candidate_services
    }

    for service, service_patterns in patterns_by_service.items():
        for service_pattern in service_patterns:
            safe_pattern = service_pattern if service_pattern.startswith(r"\b") else re.escape(service_pattern)
            for preference_pattern in PREFERENCE_PATTERNS:
                if re.search(preference_pattern.format(pattern=safe_pattern), prompt, re.IGNORECASE):
                    return service
    return None


def _normalize_top_3(
    raw_top_3: Any,
    primary_service: Optional[str],
    preferred_services: Optional[List[str]] = None,
) -> List[Dict[str, Any]]:
    confidence_by_service: Dict[str, int] = {}
    raw_order: List[str] = []

    if isinstance(raw_top_3, list):
        for item in raw_top_3:
            if not isinstance(item, dict):
                continue
            service = _normalize_service(item.get("service"))
            confidence = _normalize_confidence(item.get("confidence"))
            if not service or service in confidence_by_service:
                continue
            confidence_by_service[service] = confidence if confidence is not None else 0
            raw_order.append(service)

    ordered_services: List[str] = []
    seen = set()

    for service in [primary_service] + (preferred_services or []) + raw_order:
        if not service or service in seen:
            continue
        ordered_services.append(service)
        seen.add(service)

    for service in ALLOWED_SERVICES:
        if len(ordered_services) >= 3:
            break
        if service in seen:
            continue
        ordered_services.append(service)
        seen.add(service)

    return [
        {
            "service": service,
            "confidence": confidence_by_service.get(service, 0),
        }
        for service in ordered_services[:3]
    ]


def _detect_water_on_electrical(prompt: str) -> bool:
    for pattern in WATER_ON_ELECTRICAL_PATTERNS:
        if pattern.search(prompt):
            return True
    return False


def _detect_paint_damage(prompt: str) -> bool:
    return any(pattern.search(prompt) for pattern in PAINT_DAMAGE_PATTERNS)


def _detect_active_leak(prompt: str) -> bool:
    return any(pattern.search(prompt) for pattern in ACTIVE_LEAK_PATTERNS)


def _build_step(service: str, step_number: int, urgency: str) -> Dict[str, Any]:
    return {
        "step": step_number,
        "service": service,
        "urgency": urgency,
        "urgency_label": URGENCY_LABELS[urgency],
    }


def _normalize_steps(
    raw_steps: Any,
    primary_service: Optional[str],
    prompt: str,
    explicit_services: Optional[List[str]] = None,
) -> List[Dict[str, Any]]:
    if _detect_water_on_electrical(prompt):
        safety_services = ["Electrical", "Plumbing"]
        extra_services = [
            service for service in (explicit_services or [])
            if service not in safety_services
        ]
        ordered_services = safety_services + extra_services
        return [
            _build_step(
                service,
                index + 1,
                (
                    "urgent" if index == 0
                    else "same_day" if service == "Plumbing"
                    else "low" if service == "Painting"
                    else "high"
                ),
            )
            for index, service in enumerate(ordered_services)
        ]

    draft_steps: List[Dict[str, str]] = []
    seen = set()

    if explicit_services:
        draft_steps = [
            {
                "service": service,
                "urgency": "urgent" if index == 0 else "high",
            }
            for index, service in enumerate(explicit_services)
        ]
        seen = {item["service"] for item in draft_steps}

    if not draft_steps and isinstance(raw_steps, list):
        for item in raw_steps:
            if not isinstance(item, dict):
                continue
            service = _normalize_service(item.get("service"))
            urgency = item.get("urgency")
            if urgency not in URGENCY_LABELS:
                urgency = "high"
            if not service or service in seen:
                continue
            draft_steps.append({"service": service, "urgency": urgency})
            seen.add(service)

    if primary_service and primary_service not in seen and not explicit_services:
        draft_steps.insert(0, {"service": primary_service, "urgency": "urgent"})

    if not draft_steps:
        return []

    if len(draft_steps) == 1:
        draft_steps[0]["urgency"] = "urgent"
    else:
        urgent_index = next(
            (index for index, item in enumerate(draft_steps) if item["urgency"] == "urgent"),
            0,
        )
        ordered = [draft_steps[urgent_index]] + [
            item for index, item in enumerate(draft_steps) if index != urgent_index
        ]
        ordered[0]["urgency"] = "urgent"
        for item in ordered[1:]:
            if item["urgency"] == "urgent":
                item["urgency"] = "high"
        draft_steps = ordered

    return [
        _build_step(item["service"], index + 1, item["urgency"])
        for index, item in enumerate(draft_steps)
    ]


def _build_fallback_advisor_message(
    primary_service: Optional[str],
    steps: List[Dict[str, Any]],
    needs_follow_up: bool,
    safety_risk: bool,
) -> str:
    if safety_risk:
        services = {step.get("service") for step in steps}
        painting_note = (
            " Schedule painting after the wall is dry and the leak is fixed."
            if "Painting" in services
            else ""
        )
        return (
            "Electrical should be handled first because water contacting electrical hardware is a safety risk. "
            "Stop using that area and book plumbing the same day to stop the leak."
            f"{painting_note}"
        )

    if not primary_service:
        return "Add a clearer description so Servio can identify the right service."

    if needs_follow_up:
        return (
            f"{primary_service} looks like the best match so far. "
            "Add the missing details below so Servio can recommend the right technician."
        )

    if len(steps) > 1:
        return (
            f"{primary_service} is the most urgent issue from what you described. "
            "You can still choose another service first if that is your priority."
        )

    return f"{primary_service} looks like the right first booking based on what you described."


def _build_safety_warning(prompt: str, steps: List[Dict[str, Any]]) -> Optional[Dict[str, str]]:
    if not _detect_water_on_electrical(prompt):
        return None

    has_leak = any(step.get("service") == "Plumbing" for step in steps)
    detail = (
        "Water is reaching an electrical component. Keep the breaker off until a licensed electrician checks it."
    )
    if has_leak:
        detail += " Stop the leak the same day to prevent more damage."

    return {
        "severity": "danger",
        "title": "Keep the breaker off until the panel and leak are inspected.",
        "message": detail,
        "primary_action": "Book Electrical first",
    }


def _build_issues(prompt: str, steps: List[Dict[str, Any]]) -> List[Dict[str, str]]:
    issues: List[Dict[str, str]] = []
    service_set = {step.get("service") for step in steps}

    if "Electrical" in service_set and _detect_water_on_electrical(prompt):
        issues.append({
            "service": "Electrical",
            "title": "Electrical hazard",
            "summary": "Water is near an electrical panel or wiring.",
            "severity": "danger",
            "timing": "Book first",
        })

    if "Plumbing" in service_set and (_detect_water_on_electrical(prompt) or _detect_active_leak(prompt)):
        issues.append({
            "service": "Plumbing",
            "title": "Active leak",
            "summary": "Water is still dripping and needs same-day attention.",
            "severity": "warning",
            "timing": "Same day",
        })

    if "Painting" in service_set and _detect_paint_damage(prompt):
        issues.append({
            "service": "Painting",
            "title": "Paint damage",
            "summary": "Paint or wall finish is bubbling from moisture.",
            "severity": "info",
            "timing": "Schedule later",
        })

    for step in steps:
        service = step.get("service")
        if not service or any(issue["service"] == service for issue in issues):
            continue
        issues.append({
            "service": service,
            "title": f"{service} issue",
            "summary": f"{service} support is needed.",
            "severity": "info",
            "timing": step.get("urgency_label", "Review"),
        })

    return issues


def _compute_missing_fields(
    primary_service: Optional[str],
    extracted: Dict[str, Optional[str]],
    problem_understood: bool,
) -> Tuple[List[str], List[str]]:
    """Returns (blocking_fields, advisory_fields).
    blocking_fields: only 'problem_details' — forces scenario=vague.
    advisory_fields: location/budget/time — shown as chips, never block.
    """
    blocking: List[str] = []
    advisory: List[str] = []

    if not extracted.get("location"):
        advisory.append("location")
    if not extracted.get("budget"):
        advisory.append("budget")
    if not extracted.get("time_range"):
        advisory.append("time_range")
    if not primary_service or not problem_understood:
        blocking.append("problem_details")

    return blocking, advisory


def _build_advisory_message(advisory_fields: List[str]) -> str:
    """Soft hint shown below technicians — never a blocker."""
    if not advisory_fields:
        return ""
    labels = [MISSING_FIELD_LABELS[f] for f in advisory_fields]
    return "For closer matches, add: " + ", ".join(labels) + "."


def _build_follow_up_message(
    primary_service: Optional[str],
    blocking_fields: List[str],
    issue_mode: str,
) -> str:
    if not blocking_fields:
        return ""
    if issue_mode == "unrecognized":
        return (
            "I could not identify a home service from that request. "
            "Describe the problem in more detail so Servio can match the right technician."
        )
    return "I need a bit more detail before I can match the right service."


def _normalize_model_result(prompt: str, raw_result: Dict[str, Any]) -> Dict[str, Any]:
    raw_primary_service = _normalize_service(raw_result.get("service"))
    explicit_services = _extract_explicit_services(prompt)
    explicit_services = _disambiguate_appliance_vs_electrical(prompt, explicit_services)
    confidence = _normalize_confidence(raw_result.get("confidence"))
    extracted = {
        "location": _sanitize_location(raw_result.get("location")) or _extract_location(prompt),
        "budget": _clean_text(raw_result.get("budget")) or _extract_budget(prompt),
        "time_range": _clean_text(raw_result.get("time_range")) or _extract_time_range(prompt),
    }
    safety_risk = _detect_water_on_electrical(prompt)
    problem_understood = bool(explicit_services or safety_risk)

    if not problem_understood or not _has_meaningful_text(prompt):
        normalized = _build_unrecognized_result(prompt, extracted)
        normalized["raw_prediction"] = _clean_text(raw_result.get("service"))
        return normalized

    steps = _normalize_steps(
        raw_result.get("steps"),
        raw_primary_service,
        prompt,
        explicit_services=explicit_services,
    )

    primary_service = raw_primary_service
    if steps:
        primary_service = steps[0]["service"]

    top_3 = _normalize_top_3(
        raw_result.get("top_3"),
        primary_service,
        preferred_services=explicit_services,
    )
    if not primary_service and top_3:
        primary_service = top_3[0]["service"]

    if not steps and primary_service:
        steps = [_build_step(primary_service, 1, "urgent")]

    issue_mode = "multi" if len(steps) > 1 else "single"
    blocking_fields, advisory_fields = _compute_missing_fields(
        primary_service,
        extracted,
        problem_understood=problem_understood,
    )
    needs_follow_up = bool(blocking_fields)
    scenario = "vague" if needs_follow_up else issue_mode
    user_selected_service = _detect_user_selected_service(
        prompt,
        [step["service"] for step in steps],
    )

    advisor_message = (
        None if safety_risk else _clean_text(raw_result.get("advisor_message"))
    ) or _build_fallback_advisor_message(
        primary_service=primary_service,
        steps=steps,
        needs_follow_up=needs_follow_up,
        safety_risk=safety_risk,
    )
    safety_warning = _build_safety_warning(prompt, steps)
    issues = _build_issues(prompt, steps)

    return {
        "recommended_service": primary_service,
        "confidence": confidence if confidence is not None else 0,
        "extracted": extracted,
        "steps": steps,
        "advisor_message": advisor_message,
        "top_3": top_3,
        "raw_prediction": _clean_text(raw_result.get("service")),
        "confidence_gate_triggered": confidence is None or confidence < 50,
        "issue_mode": issue_mode,
        "needs_follow_up": needs_follow_up,
        "scenario": scenario,
        "missing_fields": blocking_fields,
        "missing_field_labels": [MISSING_FIELD_LABELS[f] for f in blocking_fields],
        "advisory_missing_fields": advisory_fields,
        "advisory_missing_field_labels": [MISSING_FIELD_LABELS[f] for f in advisory_fields],
        "follow_up_message": _build_follow_up_message(
            primary_service=primary_service,
            blocking_fields=blocking_fields,
            issue_mode=issue_mode,
        ),
        "advisory_message_missing": _build_advisory_message(advisory_fields),
        "service_options": [step["service"] for step in steps],
        "selected_service": user_selected_service or (steps[0]["service"] if steps else primary_service),
        "safety_risk": safety_risk,
        "safety_warning": safety_warning,
        "issues": issues,
    }


@app.get("/")
def root():
    return {"status": "running", "message": "Servio AI Recommender is online"}


@app.post("/recommend")
def recommend(request: PromptRequest):
    prompt = request.prompt.strip()

    if not prompt:
        return {"error": "Please describe your issue"}

    if not _has_meaningful_text(prompt):
        result = _build_unrecognized_result(prompt, {})
        result["prompt"] = prompt
        return result

    explicit_services = _extract_explicit_services(prompt)
    explicit_services = _disambiguate_appliance_vs_electrical(prompt, explicit_services)
    safety_risk = _detect_water_on_electrical(prompt)
    problem_understood = bool(explicit_services or safety_risk)

    if not problem_understood:
        extracted = {
            "location": _extract_location(prompt),
            "budget": _extract_budget(prompt),
            "time_range": _extract_time_range(prompt),
        }
        if _has_home_context(prompt):
            result = _build_vague_home_result(prompt, extracted)
        else:
            result = _build_unrecognized_result(prompt, extracted)
        result["prompt"] = prompt
        return result

    try:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            temperature=0.1,
            response_format={"type": "json_object"},
        )

        raw_content = response.choices[0].message.content or "{}"
        raw_result = json.loads(raw_content)
        if not isinstance(raw_result, dict):
            raise ValueError("Model response was not a JSON object")

        normalized = _normalize_model_result(prompt=prompt, raw_result=raw_result)
        normalized["prompt"] = prompt
        return normalized

    except Exception as exc:
        return {"error": f"AI error: {str(exc)}"}
