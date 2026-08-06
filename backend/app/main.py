from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .schemas import AnalyzeMealRequest, AnalyzeMealResponse, DailyAdviceRequest, DailyAdviceResponse
from .services import analyze_meal, create_daily_advice

app = FastAPI(title="AI Diet Coach API", version="0.1.0")

# Restrict this list to actual app domains before deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/v1/meals/analyze", response_model=AnalyzeMealResponse)
def analyze_meal_endpoint(request: AnalyzeMealRequest) -> AnalyzeMealResponse:
    return analyze_meal(request.notes)


@app.post("/api/v1/coach/daily-advice", response_model=DailyAdviceResponse)
def daily_advice_endpoint(request: DailyAdviceRequest) -> DailyAdviceResponse:
    return create_daily_advice(request)
