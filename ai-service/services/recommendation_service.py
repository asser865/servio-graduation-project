import numpy as np
from sklearn.metrics.pairwise import cosine_similarity


def build_provider_vector(provider: dict) -> list:
    """Convert a provider record into a numeric feature vector. All values normalized to [0, 1]."""
    return [
        provider.get("rating", 3.0) / 5.0,
        min(provider.get("experience_years", 1), 20) / 20.0,
        1.0 - min(provider.get("price_level", 2), 3) / 3.0,
        provider.get("completion_rate", 0.8),
        provider.get("response_time_hours", 24) / 24.0 * -1 + 1,
    ]


def build_user_vector(request: dict) -> list:
    """Convert user request into matching feature vector."""
    budget_map = {"low": 1.0, "medium": 0.5, "high": 0.0}
    return [
        0.8,
        0.5,
        budget_map.get(request.get("budget_level", "medium"), 0.5),
        0.9,
        0.7,
    ]


def recommend_providers(
    user_request: dict,
    all_providers: list,
    top_k: int = 5
) -> list:
    """
    Return top_k providers ranked by cosine similarity to user request.

    user_request: {service_type, location, budget_level, user_id}
    all_providers: list of provider dicts from DB
    """
    service_type = user_request.get("service_type", "")
    filtered = [
        p for p in all_providers
        if service_type in p.get("service_categories", [])
    ]

    if not filtered:
        filtered = all_providers

    user_vec      = np.array([build_user_vector(user_request)])
    provider_vecs = np.array([build_provider_vector(p) for p in filtered])

    scores = cosine_similarity(user_vec, provider_vecs)[0]

    ranked_indices = np.argsort(scores)[::-1][:top_k]

    results = []
    for idx in ranked_indices:
        provider = filtered[idx].copy()
        provider["match_score"] = round(float(scores[idx]), 3)
        results.append(provider)

    return results
