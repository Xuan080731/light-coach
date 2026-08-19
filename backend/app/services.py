from .schemas import AnalyzeMealResponse, DailyAdviceRequest, DailyAdviceResponse, FoodItem


def analyze_meal(notes: str) -> AnalyzeMealResponse:
    """Produce a transparent text-based estimate for the MVP.

    This endpoint intentionally does not claim to inspect an image. A production
    integration should use a nutrition database and confirm portions with the user.
    """
    text = notes.lower()
    if any(word in text for word in ("便當", "bento")):
        items = [
            FoodItem(name="白飯", estimated_grams=180, calories=234, protein_g=4.3, carbs_g=51.5, fat_g=0.5, fiber_g=0.7),
            FoodItem(name="雞腿肉", estimated_grams=130, calories=280, protein_g=30, carbs_g=2, fat_g=16, fiber_g=0),
            FoodItem(name="配菜", estimated_grams=120, calories=70, protein_g=3, carbs_g=9, fat_g=2.5, fiber_g=3.5),
        ]
    elif "沙拉" in text:
        items = [FoodItem(name="沙拉（含醬料估算）", estimated_grams=280, calories=280, protein_g=14, carbs_g=20, fat_g=16, fiber_g=7)]
    else:
        items = [FoodItem(name="餐點文字估算", estimated_grams=250, calories=450, protein_g=20, carbs_g=50, fat_g=18, fiber_g=4)]
    return AnalyzeMealResponse(
        items=items,
        total_calories=sum(item.calories for item in items),
        total_protein_g=round(sum(item.protein_g for item in items), 1),
        total_carbs_g=round(sum(item.carbs_g for item in items), 1),
        total_fat_g=round(sum(item.fat_g for item in items), 1),
        total_fiber_g=round(sum(item.fiber_g for item in items), 1),
        confidence=0.62,
        disclaimer="此為依文字內容產生的粗略估算，請依實際份量調整，不能作為醫療或營養處方。",
    )


def create_daily_advice(request: DailyAdviceRequest) -> DailyAdviceResponse:
    remaining = request.calorie_target - request.calories_consumed
    protein_gap = request.protein_target_g - request.protein_consumed_g
    fiber_gap = request.fiber_target_g - request.fiber_consumed_g
    if remaining < 0:
        headline = "今天的熱量已超過目標"
        advice = "下一餐可優先選擇蔬菜、蛋白質和清淡烹調，並注意飽足感。"
    elif fiber_gap > 6:
        headline = "纖維還可以再補一些"
        advice = "晚餐可增加一份青菜，或選擇芭樂、奇異果等水果，讓一天更均衡。"
    elif protein_gap > 15:
        headline = "蛋白質還可以再補一些"
        advice = "可考慮加入豆腐、雞蛋、魚、瘦肉或無糖乳製品。"
    else:
        headline = "今天的營養進度穩定"
        advice = "維持均衡飲食、適量喝水與規律作息。"
    return DailyAdviceResponse(
        headline=headline,
        advice=advice,
        remaining_calories=remaining,
        medical_disclaimer="本建議僅供一般健康管理參考，若有疾病或特殊飲食需求，請諮詢醫師或營養師。",
    )
