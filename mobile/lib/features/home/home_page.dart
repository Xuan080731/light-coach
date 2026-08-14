import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/diet_models.dart';
import '../../services/ai_service.dart';
import '../../state/diet_controller.dart';

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
    final meals = diet.mealsFor(today);
    // Activity calories are shown for reference only. They never increase the
    // daily food allowance, so the calorie target stays predictable.
    final remaining = diet.calorieTarget - calories;
    final signature =
        '${_dateKey(today)}|${diet.trackingMode}|${meals.map((meal) => '${meal.id}:${meal.calories}:${meal.protein}').join(',')}|$calories|$protein|${diet.totalStepsToday}|${diet.totalExerciseMinutesToday}|${diet.estimatedActivityCalories}|${diet.calorieTarget}|${diet.proteinTarget}|${diet.activeCalorieTarget}|${diet.weightTarget}';
    if (diet.hasChosenTrackingMode &&
        _cacheReady &&
        signature != _adviceSignature &&
        !_loading) {
      _adviceSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadAdvice(diet, meals, calories, protein, signature));
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
              color: color),
          const SizedBox(height: 12),
          _ProgressCard(
              title: '蛋白質',
              progress: _progress(protein, diet.proteinTarget),
              value:
                  '${protein.toStringAsFixed(0)} / ${diet.proteinTarget.toStringAsFixed(0)} g',
              color: color.secondary),
          const SizedBox(height: 12),
          if (diet.usesHealthConnect)
            _ProgressCard(
                title: '消耗卡路里',
                progress: _progress(
                    diet.estimatedActivityCalories, diet.activeCalorieTarget),
                value:
                    '${diet.estimatedActivityCalories} / ${diet.activeCalorieTarget} kcal',
                color: color.tertiary),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
                child: Text('今日 AI 建議',
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

  Future<void> _loadAdvice(DietController diet, List<MealEntry> meals,
      int calories, double protein, String signature) async {
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
                    '${meal.mealType}：${meal.name}（${meal.calories} kcal，蛋白質 ${meal.protein.toStringAsFixed(0)} g）')
                .join('；'),
        caloriesConsumed: calories,
        calorieTarget: diet.calorieTarget,
        proteinConsumed: protein,
        proteinTarget: diet.proteinTarget,
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

  static double _progress(num value, num target) =>
      target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble();

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard(
      {required this.title,
      required this.progress,
      required this.value,
      required this.color});
  final String title;
  final double progress;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, color: color)
          ])));
}

class _DailyEnergyCard extends StatelessWidget {
  const _DailyEnergyCard(
      {required this.calories,
      required this.baseTarget,
      required this.remaining,
      required this.color});

  final int calories;
  final int baseTarget;
  final int remaining;
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
