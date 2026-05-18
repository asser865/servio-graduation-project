from fastapi import APIRouter
from pydantic import BaseModel
from ai_recommender.api import recommend as _groq_recommend, PromptRequest

router = APIRouter()


class SmartRecommendRequest(BaseModel):
    prompt: str


@router.post("/recommend")
def smart_recommend(request: SmartRecommendRequest):
    """Forward to the Groq-based NLP recommender. Accepts { prompt: str }."""
    return _groq_recommend(PromptRequest(prompt=request.prompt))
