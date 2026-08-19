class MealEntry {
  const MealEntry({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    required this.protein,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.portionGrams,
    required this.loggedAt,
  });

  final String id;
  final String name;
  final String mealType;
  final int calories;
  final double protein;

  /// Grams of carbohydrate. Old records safely default to zero.
  final double carbs;

  /// Grams of fat. Old records safely default to zero.
  final double fat;

  /// Grams of dietary fibre. Old records safely default to zero.
  final double fiber;

  /// Optional estimated edible portion, mainly supplied by photo analysis.
  final double? portionGrams;
  final DateTime loggedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mealType': mealType,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        if (portionGrams != null) 'portionGrams': portionGrams,
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        mealType: json['mealType'] as String,
        calories: (json['calories'] as num).round(),
        protein: (json['protein'] as num? ?? 0).toDouble(),
        carbs: (json['carbs'] as num? ?? 0).toDouble(),
        fat: (json['fat'] as num? ?? 0).toDouble(),
        fiber: (json['fiber'] as num? ?? 0).toDouble(),
        portionGrams: (json['portionGrams'] as num?)?.toDouble(),
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );
}

class WeightEntry {
  const WeightEntry(
      {required this.id, required this.kilograms, required this.loggedAt});

  final String id;
  final double kilograms;
  final DateTime loggedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kilograms': kilograms,
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String,
        kilograms: (json['kilograms'] as num).toDouble(),
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );
}
