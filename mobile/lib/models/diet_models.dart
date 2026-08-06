class MealEntry {
  const MealEntry({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.loggedAt,
  });

  final String id;
  final String name;
  final String mealType;
  final int calories;
  final double protein;
  final DateTime loggedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mealType': mealType,
        'calories': calories,
        'protein': protein,
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        mealType: json['mealType'] as String,
        calories: (json['calories'] as num).round(),
        protein: (json['protein'] as num).toDouble(),
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );
}

class WeightEntry {
  const WeightEntry({required this.id, required this.kilograms, required this.loggedAt});

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
