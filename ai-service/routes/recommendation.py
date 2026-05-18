from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from services.recommendation_service import recommend_providers

router = APIRouter()


class RecommendRequest(BaseModel):
    service_type:  str
    location:      str
    budget_level:  str = "medium"    # low | medium | high
    user_id:       str = ""


@router.post("/ai/recommend")
async def recommend_endpoint(request: RecommendRequest):
    try:
        # TODO: Replace this mock list with a real DB query
        # all_providers = db.query("SELECT * FROM providers WHERE active = 1")
        all_providers = [
            {
                "id": "p1", "name": "Ahmed Hassan", "service_categories": ["plumbing", "electrical"],
                "rating": 4.8, "experience_years": 10, "price_level": 2,
                "completion_rate": 0.95, "response_time_hours": 2, "location": "Cairo"
            },
            {
                "id": "p2", "name": "Mohamed Ali", "service_categories": ["tiling", "flooring"],
                "rating": 4.5, "experience_years": 7, "price_level": 1,
                "completion_rate": 0.90, "response_time_hours": 4, "location": "Giza"
            }
        ]

        results = recommend_providers(
            user_request=request.dict(),
            all_providers=all_providers,
            top_k=5
        )

        return JSONResponse(content={"status": "success", "providers": results})

    except Exception as e:
        raise HTTPException(500, str(e))
