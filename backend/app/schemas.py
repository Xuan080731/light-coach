from typing import Literal

from pydantic import BaseModel, Field


class FoodItem(BaseModel):
    name: str
    estimated_grams: float = Field(ge=0)
    calories: int = Field(ge=0)
    protein_g: float = Field(ge=0)
    carbs_g: float = Field(ge=0)
    fat_g: float = Field(ge=0)
    fiber_g: float = Field(default=0, ge=0)


class AnalyzeMealRequest(BaseModel):
    meal_type: Literal["breakfast", "lunch", "dinner", "snack"] = "lunch"
    notes: str = Field(default="", max_length=500)
    # The app will send a photo to object storage, then provide a signed URL.
    image_url: str | None = None


class AnalyzeMealResponse(BaseModel):
    items: list[FoodItem]
    total_calories: int
    total_protein_g: float
    total_carbs_g: float = Field(default=0, ge=0)
    total_fat_g: float = Field(default=0, ge=0)
    total_fiber_g: float = Field(default=0, ge=0)
    confidence: float = Field(ge=0, le=1)
    disclaimer: str


class DailyAdviceRequest(BaseModel):
    calories_consumed: int = Field(ge=0)
    calorie_target: int = Field(gt=0)
    protein_consumed_g: float = Field(ge=0)
    protein_target_g: float = Field(gt=0)
    carbs_consumed_g: float = Field(default=0, ge=0)
    carbs_target_g: float = Field(default=200, gt=0)
    fat_consumed_g: float = Field(default=0, ge=0)
    fat_target_g: float = Field(default=60, gt=0)
    fiber_consumed_g: float = Field(default=0, ge=0)
    fiber_target_g: float = Field(default=25, gt=0)
    nutrition_score: int | None = Field(default=None, ge=0, le=100)
    meals: list[FoodItem] = Field(default_factory=list)


class DailyAdviceResponse(BaseModel):
    headline: str
    advice: str
    remaining_calories: int
    medical_disclaimer: str
