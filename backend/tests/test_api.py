from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_check() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_analyze_meal_returns_editable_estimate() -> None:
    response = client.post("/api/v1/meals/analyze", json={"meal_type": "lunch", "notes": "雞腿便當"})
    body = response.json()
    assert response.status_code == 200
    assert body["total_calories"] > 0
    assert body["confidence"] <= 1


def test_daily_advice() -> None:
    response = client.post(
        "/api/v1/coach/daily-advice",
        json={"calories_consumed": 1120, "calorie_target": 1800, "protein_consumed_g": 58, "protein_target_g": 100},
    )
    assert response.status_code == 200
    assert response.json()["remaining_calories"] == 680
