from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from room_finishing.routes.room_analysis import router as room_finishing_router
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(
    title="Servio AI Service",
    description="Room finishing analysis powered by Google Gemini Vision",
    version="1.0.0",
    docs_url="/docs",       # Interactive API docs at localhost:8001/docs
    redoc_url="/redoc"
)

# Allow your frontend and main backend to call this service
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",   # React frontend
        "http://localhost:5000",   # Node.js backend
        "http://localhost:8000",   # Django backend
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(room_finishing_router)


@app.get("/")
def health_check():
    return {"status": "Servio AI service is running", "version": "1.0.0"}
