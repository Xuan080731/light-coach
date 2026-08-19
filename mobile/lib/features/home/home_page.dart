import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/diet_models.dart';
import '../../services/ai_service.dart';
import '../../services/nutrition_score_service.dart';
import '../../state/diet_controller.dart';
import '../nutrition/nutrition_analysis_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onOpenMealLog});
  final VoidCallback onOpenMealLog;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _adviceDateKey = 'daily_advice_date';
  static const _adviceSignatureKey = 'daily_advice_signature';
  static const _adviceHeadlineKey = 'daily_advice_headline';
  static const _adviceBodyKey = 'daily_advice_body';

  AiDailyAdvice? _advice;
  String? _adviceSignature;
  String? _error;
  var _loading = false;
  var _cacheReady = false;

  @override
  void initState() {
    super.initState();
    _restoreAdvice();
  }

  Future<void> _restoreAdvice() async {
    final prefs = await SharedPreferences.getInstance();
    final headline = prefs.getString(_adviceHeadlineKey);
    final body = prefs.getString(_adviceBodyKey);
    if (prefs.getString(_adviceDateKey) == _dateKey(DateTime.now()) &&
        headline != null &&
        headline.isNotEmpty &&
        body != null &&
        body.isNotEmpty) {
      _advice = AiDailyAdvice(headline: headline, advice: body);
      _adviceSignature = prefs.getString(_adviceSignatureKey);
    }
    if (mounted) setState(() => _cacheReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    final color = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final calories = diet.caloriesFor(today);
    final protein = diet.proteinFor(today);
    final carbs = diet.carbsFor(today);
    final fat = diet.fatFor(today);
    final fiber = diet.fiberFor(today);
    final meals = diet.mealsFor(today);
    final nutritionScore = const NutritionScoreService().calculate(
      calorieIntake: calories,
      calorieTarget: diet.calorieTarget,
      proteinIntake: protein,
      proteinTarget: diet.proteinTarget,
      carbsIntake: carbs,
      carbsTarget: diet.carbsTarget,
      fatIntake: fat,
      fatTarget: diet.fatTarget,
      fiberIntake: fiber,
      fiberTarget: diet.fiberTarget,
    );
    // Activity calories are shown for reference only. They never increase the
    // daily food allowance, so the calorie target stays predictable.
    final remaining = diet.calorieTarget - calories;
    final signature =
        '${_dateKey(today)}|${diet.trackingMode}|${meals.map((meal) => '${meal.id}:${meal.calories}:${meal.protein}:${meal.carbs}:${meal.fat}:${meal.fiber}').join(',')}|$calories|$protein|$carbs|$fat|$fiber|${diet.totalStepsToday}|${diet.totalExerciseMinutesToday}|${diet.estimatedActivityCalories}|${diet.calorieTarget}|${diet.proteinTarget}|${diet.carbsTarget}|${diet.fatTarget}|${diet.fiberTarget}|${diet.activeCalorieTarget}|${diet.weightTarget}';
    if (diet.hasChosenTrackingMode &&
        _cacheReady &&
        signature != _adviceSignature &&
        !_loading) {
      _adviceSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdvice(
          diet,
          meals,
          calories,
          protein,
          carbs,
          fat,
          fiber,
          nutritionScore.totalScore,
          signature));
    }
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('今天，照顧好自己',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('記下每一餐，讓目標變得清楚。', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 22),
          _DailyEnergyCard(
              calories: calories,
              baseTarget: diet.calorieTarget,
              remaining: remaining,
              activeCalories: diet.estimatedActivityCalories,
              activeCalorieTarget: diet.activeCalorieTarget,
              color: color),
          const SizedBox(height: 12),
          _TodayNutritionCard(
              calories: calories,
              calorieTarget: diet.calorieTarget,
              protein: protein,
              proteinTarget: diet.proteinTarget,
              carbs: carbs,
              carbsTarget: diet.carbsTarget,
              fat: fat,
              fatTarget: diet.fatTarget,
              fiber: fiber,
              fiberTarget: diet.fiberTarget,
              score: nutritionScore.totalScore,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => NutritionAnalysisPage(
                      aiSummary: _advice?.advice ??
                          _fallbackNutritionSummary(
                              diet, calories, protein, carbs, fat, fiber)))),
              color: color),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
                child: Text('AI 建議',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold))),
          ]),
          Card(
              child: ListTile(
            leading: CircleAvatar(
                backgroundColor: color.secondaryContainer,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome)),
            title: Text(_advice?.headline ??
                (_error == null ? '正在準備今日建議' : '尚未取得 AI 建議')),
            subtitle:
                Text(_advice?.advice ?? (_error ?? '將依今日餐點、步數、運動與減重計畫產生建議。')),
          )),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
                child: Text('今天的餐點',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold))),
            TextButton.icon(
                onPressed: widget.onOpenMealLog,
                icon: const Icon(Icons.history),
                label: const Text('查看紀錄')),
            const SizedBox(width: 8),
            TextButton.icon(
                onPressed: widget.onOpenMealLog,
                icon: const Icon(Icons.add),
                label: const Text('新增'))
          ]),
          if (meals.isEmpty)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      const Icon(Icons.restaurant_outlined, size: 36),
                      const SizedBox(height: 8),
                      const Text('尚未記錄任何餐點'),
                      const SizedBox(height: 10),
                      OutlinedButton(
                          onPressed: widget.onOpenMealLog,
                          child: const Text('開始記錄'))
                    ])))
          else
            ...meals.map((meal) => _MealTile(meal: meal)),
        ]);
  }

  Future<void> _loadAdvice(
      DietController diet,
      List<MealEntry> meals,
      int calories,
      double protein,
      double carbs,
      double fat,
      double fiber,
      int nutritionScore,
      String signature) async {
    if (_loading || !_cacheReady) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final advice = await AiService().createDailyAdvice(
        meals: meals.isEmpty
            ? '尚未記錄餐點'
            : meals
                .map((meal) =>
                    '${meal.mealType}：${meal.name}（${meal.calories} kcal，蛋白質 ${meal.protein.toStringAsFixed(0)} g，碳水 ${meal.carbs.toStringAsFixed(0)} g，脂肪 ${meal.fat.toStringAsFixed(0)} g，纖維 ${meal.fiber.toStringAsFixed(0)} g）')
                .join('；'),
        caloriesConsumed: calories,
        calorieTarget: diet.calorieTarget,
        proteinConsumed: protein,
        proteinTarget: diet.proteinTarget,
        carbsConsumed: carbs,
        carbsTarget: diet.carbsTarget,
        fatConsumed: fat,
        fatTarget: diet.fatTarget,
        fiberConsumed: fiber,
        fiberTarget: diet.fiberTarget,
        nutritionScore: nutritionScore,
        steps: diet.totalStepsToday,
        exerciseMinutes: diet.totalExerciseMinutesToday,
        activeCalories: diet.estimatedActivityCalories,
        activeCaloriesTarget: diet.activeCalorieTarget,
        goalWeight: diet.weightTarget,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_adviceDateKey, _dateKey(DateTime.now()));
      await prefs.setString(_adviceSignatureKey, signature);
      await prefs.setString(_adviceHeadlineKey, advice.headline);
      await prefs.setString(_adviceBodyKey, advice.advice);
      if (mounted) {
        setState(() {
          _advice = advice;
          _adviceSignature = signature;
        });
      }
    } catch (error) {
      if (mounted)
        setState(() => _error = error is AiServiceException
            ? error.message
            : '無法取得 AI 建議，請檢查網路與 AI 服務設定。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _fallbackNutritionSummary(DietController diet, int calories,
      double protein, double carbs, double fat, double fiber) {
    final gaps = <String>[];
    if (protein < diet.proteinTarget * 0.9) gaps.add('蛋白質');
    if (fiber < diet.fiberTarget * 0.9) gaps.add('膳食纖維');
    if (gaps.isNotEmpty) {
      return '${gaps.join('與')}還有一些空間；下一餐可用一份容易準備的食物慢慢補足。';
    }
    if (calories > diet.calorieTarget ||
        carbs > diet.carbsTarget ||
        fat > diet.fatTarget) {
      return '今天已有部分營養素超過目標，接下來可優先選擇蔬菜與原型蛋白質，保持彈性即可。';
    }
    return '熱量與主要營養素進度穩定，持續依飽足感安排下一餐。';
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}

class _TodayNutritionCard extends StatelessWidget {
  const _TodayNutritionCard({
    required this.calories,
    required this.calorieTarget,
    required this.protein,
    required this.proteinTarget,
    required this.carbs,
    required this.carbsTarget,
    required this.fat,
    required this.fatTarget,
    required this.fiber,
    required this.fiberTarget,
    required this.score,
    required this.onTap,
    required this.color,
  });

  final int calories;
  final int calorieTarget;
  final double protein;
  final double proteinTarget;
  final double carbs;
  final double carbsTarget;
  final double fat;
  final double fatTarget;
  final double fiber;
  final double fiberTarget;
  final int score;
  final VoidCallback onTap;
  final ColorScheme color;

  @override
  Widget build(BuildContext context) => Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('今日營養',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold))),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: color.secondaryContainer,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('分數 $score',
                              style: TextStyle(
                                  color: color.onSecondaryContainer,
                                  fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 14),
                    _NutritionLine(
                        label: '熱量',
                        value: '$calories / $calorieTarget kcal',
                        progress: _safeProgress(calories, calorieTarget),
                        color: color.primary),
                    _NutritionLine(
                        label: '蛋白質',
                        value:
                            '${protein.toStringAsFixed(0)} / ${proteinTarget.toStringAsFixed(0)} g',
                        progress: _safeProgress(protein, proteinTarget),
                        color: color.secondary),
                    _NutritionLine(
                        label: '碳水',
                        value:
                            '${carbs.toStringAsFixed(0)} / ${carbsTarget.toStringAsFixed(0)} g',
                        progress: _safeProgress(carbs, carbsTarget),
                        color: color.tertiary),
                    _NutritionLine(
                        label: '脂肪',
                        value:
                            '${fat.toStringAsFixed(0)} / ${fatTarget.toStringAsFixed(0)} g',
                        progress: _safeProgress(fat, fatTarget),
                        color: color.error),
                    _NutritionLine(
                        label: '纖維',
                        value:
                            '${fiber.toStringAsFixed(0)} / ${fiberTarget.toStringAsFixed(0)} g',
                        progress: _safeProgress(fiber, fiberTarget),
                        color: color.primary),
                  ]))));
}

class _NutritionLine extends StatelessWidget {
  const _NutritionLine(
      {required this.label,
      required this.value,
      required this.progress,
      required this.color});

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 58, child: Text(label)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: progress, color: color, minHeight: 5),
      ]));
}

class _DailyEnergyCard extends StatelessWidget {
  const _DailyEnergyCard(
      {required this.calories,
      required this.baseTarget,
      required this.remaining,
      required this.activeCalories,
      required this.activeCalorieTarget,
      required this.color});

  final int calories;
  final int baseTarget;
  final int remaining;
  final int activeCalories;
  final int activeCalorieTarget;
  final ColorScheme color;

  @override
  Widget build(BuildContext context) {
    return Card(
        color: color.primary.withOpacity(
            Theme.of(context).brightness == Brightness.light ? 0.10 : 0.18),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: color.primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.local_fire_department_outlined,
                        color: color.primary)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('今日熱量摘要',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ])),
              ]),
              const SizedBox(height: 20),
              Text(remaining >= 0 ? '還可攝取' : '已超過',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text('${remaining.abs()} kcal',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: color.onPrimaryContainer,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                  value: _safeProgress(calories, baseTarget),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 24),
              Text('消耗卡路里', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text('$activeCalories kcal',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: color.onPrimaryContainer,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                  value: _safeProgress(activeCalories, activeCalorieTarget),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: color.tertiary),
              const SizedBox(height: 16),
              Row(children: [
                _EnergyFact(label: '基本目標', value: '$baseTarget kcal'),
                const SizedBox(width: 12),
                _EnergyFact(label: '已攝取', value: '$calories kcal'),
              ]),
            ])));
  }
}

class _EnergyFact extends StatelessWidget {
  const _EnergyFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ]));
}

double _safeProgress(num value, num target) =>
    target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble();

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal});
  final MealEntry meal;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: CircleAvatar(child: Icon(_iconFor(meal.mealType))),
          title: Text(meal.name),
          subtitle: Text(meal.mealType),
          trailing: Text(
              '${meal.calories} kcal\n${meal.protein.toStringAsFixed(0)} g',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold))));
  IconData _iconFor(String type) => switch (type) {
        '早餐' => Icons.free_breakfast_outlined,
        '午餐' => Icons.lunch_dining_outlined,
        '晚餐' => Icons.dinner_dining_outlined,
        _ => Icons.cookie_outlined
      };
}
