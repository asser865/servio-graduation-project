from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.room_analysis import router as room_router
from routes.recommendation import router as rec_router
from routes.cost_estimator import router as cost_router
from routes.smart_recommend import router as smart_rec_router
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(
    title="Servio AI Service",
    description="AI microservice for room finishing analysis, recommendations, and cost estimation",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",   # React frontend
        "http://localhost:5000",   # Node.js backend
        "http://localhost:8000",   # Django backend
        "http://127.0.0.1:5500",   # VS Code Live Server
        "http://localhost:5500",
        "null",                    # file:// origin (HTML opened directly)
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(room_router)
app.include_router(rec_router)
app.include_router(cost_router)
app.include_router(smart_rec_router)


@app.get("/")
def health_check():
    return {
        "status":  "Servio AI service is running",
        "version": "1.0.0",
        "endpoints": [
            "POST /ai/analyze-room",
            "POST /ai/recommend",
            "POST /ai/estimate-cost",
            "POST /recommend"
        ]
    }
