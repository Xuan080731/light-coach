/// Deterministic daily nutrition scoring.
///
/// The score deliberately gives small overages a gentle penalty and never asks
/// an AI model to choose a number. AI is only used to explain this result.
class NutritionScore {
  const NutritionScore({
    required this.totalScore,
    required this.calorieScore,
    required this.proteinScore,
    required this.carbsScore,
    required this.fatScore,
    required this.fiberScore,
  });

  final int totalScore;
  final int calorieScore;
  final int proteinScore;
  final int carbsScore;
  final int fatScore;
  final int fiberScore;
}

class NutritionScoreService {
  const NutritionScoreService();

  static const calorieWeight = 30;
  static const proteinWeight = 25;
  static const carbsWeight = 15;
  static const fatWeight = 15;
  static const fiberWeight = 15;

  NutritionScore calculate({
    required num calorieIntake,
    required num calorieTarget,
    required num proteinIntake,
    required num proteinTarget,
    required num carbsIntake,
    required num carbsTarget,
    required num fatIntake,
    required num fatTarget,
    required num fiberIntake,
    required num fiberTarget,
  }) {
    final calorieScore = _weightedScore(
        _balancedRatio(calorieIntake, calorieTarget,
            lowerComfort: 0.85, upperComfort: 1.10, upperZero: 2.0),
        calorieWeight);
    final proteinScore = _weightedScore(
        _minimumRatio(proteinIntake, proteinTarget, fullAt: 0.90),
        proteinWeight);
    final carbsScore = _weightedScore(
        _balancedRatio(carbsIntake, carbsTarget,
            lowerComfort: 0.80, upperComfort: 1.20, upperZero: 2.0),
        carbsWeight);
    final fatScore = _weightedScore(
        _balancedRatio(fatIntake, fatTarget,
            lowerComfort: 0.80, upperComfort: 1.20, upperZero: 2.0),
        fatWeight);
    final fiberScore = _weightedScore(
        _minimumRatio(fiberIntake, fiberTarget, fullAt: 0.90), fiberWeight);
    return NutritionScore(
      totalScore:
          calorieScore + proteinScore + carbsScore + fatScore + fiberScore,
      calorieScore: calorieScore,
      proteinScore: proteinScore,
      carbsScore: carbsScore,
      fatScore: fatScore,
      fiberScore: fiberScore,
    );
  }

  static int _weightedScore(double ratioScore, int weight) =>
      (ratioScore.clamp(0, 1) * weight).round();

  /// Scores a nutrient that benefits from reaching, but not exceeding, a goal.
  /// Values inside the comfort range receive full credit; outside it the score
  /// decreases linearly, so a modest one-day overage is not heavily penalised.
  static double _balancedRatio(num intake, num target,
      {required double lowerComfort,
      required double upperComfort,
      required double upperZero}) {
    if (target <= 0) return 1;
    final ratio = (intake / target).clamp(0, double.infinity).toDouble();
    if (ratio >= lowerComfort && ratio <= upperComfort) return 1;
    if (ratio < lowerComfort) return ratio / lowerComfort;
    return 1 - ((ratio - upperComfort) / (upperZero - upperComfort));
  }

  /// Scores adequacy-only nutrients such as protein and fibre. Extra intake is
  /// not penalised here because the targets are practical minimums.
  static double _minimumRatio(num intake, num target,
      {required double fullAt}) {
    if (target <= 0) return 1;
    return ((intake / target) / fullAt).clamp(0, 1).toDouble();
  }
}
