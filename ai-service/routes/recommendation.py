import os
import urllib.request
import urllib.parse
import json as _json

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from services.recommendation_service import recommend_providers

router = APIRouter()

# URL of the Node.js backend — set via environment variable
_BACKEND_URL = os.getenv("BACKEND_API_URL", "http://localhost:5000")

# Extended static provider list used when the backend is unreachable.
# 10 providers across service types so cosine matching has meaningful input.
_FALLBACK_PROVIDERS = [
    {
        "id": "p1", "name": "Ahmed Hassan",
        "service_categories": ["plumbing", "electrical"],
        "rating": 4.8, "experience_years": 10, "price_level": 2,
        "completion_rate": 0.95, "response_time_hours": 2, "location": "Cairo",
    },
    {
        "id": "p2", "name": "Mohamed Ali",
        "service_categories": ["tiling", "flooring"],
        "rating": 4.5, "experience_years": 7, "price_level": 1,
        "completion_rate": 0.90, "response_time_hours": 4, "location": "Giza",
    },
    {
        "id": "p3", "name": "Karim Samir",
        "service_categories": ["painting", "plastering"],
        "rating": 4.7, "experience_years": 8, "price_level": 2,
        "completion_rate": 0.93, "response_time_hours": 3, "location": "Cairo",
    },
    {
        "id": "p4", "name": "Youssef Ibrahim",
        "service_categories": ["carpentry", "doors", "windows"],
        "rating": 4.6, "experience_years": 12, "price_level": 2,
        "completion_rate": 0.91, "response_time_hours": 5, "location": "Cairo",
    },
    {
        "id": "p5", "name": "Hassan Mostafa",
        "service_categories": ["electrical", "lighting"],
        "rating": 4.9, "experience_years": 15, "price_level": 3,
        "completion_rate": 0.97, "response_time_hours": 2, "location": "Giza",
    },
    {
        "id": "p6", "name": "Amr Fouad",
        "service_categories": ["plumbing", "bathroom"],
        "rating": 4.4, "experience_years": 6, "price_level": 1,
        "completion_rate": 0.88, "response_time_hours": 6, "location": "Cairo",
    },
    {
        "id": "p7", "name": "Sherif Nabil",
        "service_categories": ["tiling", "flooring", "marble"],
        "rating": 4.8, "experience_years": 11, "price_level": 3,
        "completion_rate": 0.96, "response_time_hours": 3, "location": "Cairo",
    },
    {
        "id": "p8", "name": "Tarek Salah",
        "service_categories": ["painting", "interior finishing"],
        "rating": 4.3, "experience_years": 5, "price_level": 1,
        "completion_rate": 0.85, "response_time_hours": 8, "location": "Alexandria",
    },
    {
        "id": "p9", "name": "Omar Khalil",
        "service_categories": ["carpentry", "kitchen cabinets"],
        "rating": 4.7, "experience_years": 9, "price_level": 2,
        "completion_rate": 0.92, "response_time_hours": 4, "location": "Giza",
    },
    {
        "id": "p10", "name": "Walid Mansour",
        "service_categories": ["electrical", "plumbing", "general"],
        "rating": 4.5, "experience_years": 14, "price_level": 2,
        "completion_rate": 0.94, "response_time_hours": 3, "location": "Cairo",
    },
]


def _fetch_providers_from_backend(service_type: str, location: str) -> list:
    """
    Try to fetch real worker/provider records from the Node.js backend.
    Returns a list of provider dicts compatible with recommend_providers(),
    or an empty list if the backend is unreachable.
    """
    try:
        params = urllib.parse.urlencode({
            "serviceType": service_type,
            "location":    location,
            "limit":       50,
        })
        url = f"{_BACKEND_URL}/api/workers?{params}"
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=3) as resp:
            body   = resp.read().decode("utf-8")
            data   = _json.loads(body)
            workers = data.get("data", data.get("workers", []))

        providers = []
        for w in workers:
            # Map backend worker schema → recommendation service vector schema
            providers.append({
                "id":                  str(w.get("_id", w.get("id", ""))),
                "name":                w.get("name", ""),
                "service_categories":  w.get("serviceCategories", w.get("services", [])),
                "rating":              float(w.get("rating", 3.5)),
                "experience_years":    int(w.get("yearsOfExperience", 1)),
                "price_level":         int(w.get("priceLevel", 2)),
                "completion_rate":     float(w.get("completionRate", 0.85)),
                "response_time_hours": float(w.get("avgResponseTimeHours", 12)),
                "location":            w.get("location", {}).get("city", ""),
            })
        return providers

    except Exception as exc:
        print(f"Backend provider fetch failed (using fallback): {exc}")
        return []


class RecommendRequest(BaseModel):
    service_type:  str
    location:      str
    budget_level:  str = "medium"   # low | medium | high
    user_id:       str = ""


@router.post("/ai/recommend")
async def recommend_endpoint(request: RecommendRequest):
    try:
        all_providers = _fetch_providers_from_backend(
            request.service_type, request.location
        )

        if not all_providers:
            all_providers = _FALLBACK_PROVIDERS

        results = recommend_providers(
            user_request=request.dict(),
            all_providers=all_providers,
            top_k=5,
        )

        return JSONResponse(content={
            "status":    "success",
            "providers": results,
            "source":    "backend" if len(all_providers) > len(_FALLBACK_PROVIDERS) else "fallback",
        })

    except Exception as e:
        raise HTTPException(500, str(e))
