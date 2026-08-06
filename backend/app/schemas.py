from typing import Literal

from pydantic import BaseModel, Field


class FoodItem(BaseModel):
    name: str
    estimated_grams: float = Field(ge=0)
    calories: int = Field(ge=0)
    protein_g: float = Field(ge=0)
    carbs_g: float = Field(ge=0)
    fat_g: float = Field(ge=0)


class AnalyzeMealRequest(BaseModel):
    meal_type: Literal["breakfast", "lunch", "dinner", "snack"] = "lunch"
    notes: str = Field(default="", max_length=500)
    # The app will send a photo to object storage, then provide a signed URL.
    image_url: str | None = None


class AnalyzeMealResponse(BaseModel):
    items: list[FoodItem]
    total_calories: int
    total_protein_g: float
    confidence: float = Field(ge=0, le=1)
    disclaimer: str


class DailyAdviceRequest(BaseModel):
    calories_consumed: int = Field(ge=0)
    calorie_target: int = Field(gt=0)
    protein_consumed_g: float = Field(ge=0)
    protein_target_g: float = Field(gt=0)


class DailyAdviceResponse(BaseModel):
    headline: str
    advice: str
    remaining_calories: int
    medical_disclaimer: str
