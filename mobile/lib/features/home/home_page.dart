import 'package:flutter/material.dart';

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
  AiDailyAdvice? _advice;
  String? _signature;
  String? _error;
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    final color = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final calories = diet.caloriesFor(today);
    final protein = diet.proteinFor(today);
    final meals = diet.mealsFor(today);
    final remaining = diet.calorieTarget - calories;
    final signature = '${meals.map((meal) => '${meal.id}:${meal.calories}:${meal.protein}').join(',')}|$calories|$protein|${diet.totalStepsToday}|${diet.totalExerciseMinutesToday}|${diet.exerciseType}|${diet.estimatedActivityCalories}|${diet.calorieTarget}|${diet.proteinTarget}|${diet.activeCalorieTarget}|${diet.weightTarget}';
    if (signature != _signature && !_loading) {
      _signature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdvice(diet, meals, calories, protein));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 32), children: [
      Text('今天，照顧好自己', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4), Text('記下每一餐，讓目標變得清楚。', style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 22),
      Card(color: color.primaryContainer, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('今日熱量', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
        Text('$calories / ${diet.calorieTarget} kcal', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: color.onPrimaryContainer, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
        LinearProgressIndicator(value: _progress(calories, diet.calorieTarget)), const SizedBox(height: 8),
        Text(remaining >= 0 ? '還可攝取 $remaining kcal' : '已超過目標 ${-remaining} kcal'),
      ]))),
      const SizedBox(height: 12),
      _ProgressCard(title: '蛋白質', progress: _progress(protein, diet.proteinTarget), value: '${protein.toStringAsFixed(0)} / ${diet.proteinTarget.toStringAsFixed(0)} g', color: color.secondary),
      const SizedBox(height: 12),
      _ProgressCard(title: '活動消耗', progress: _progress(diet.estimatedActivityCalories, diet.activeCalorieTarget), value: '${diet.estimatedActivityCalories} / ${diet.activeCalorieTarget} kcal', color: color.tertiary),
      const SizedBox(height: 22),
      Row(children: [Expanded(child: Text('今日 AI 建議', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), IconButton(onPressed: _loading ? null : () => _loadAdvice(diet, meals, calories, protein, force: true), tooltip: '重新產生建議', icon: const Icon(Icons.refresh))]),
      Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: color.secondaryContainer, child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome)),
        title: Text(_advice?.headline ?? (_error == null ? '正在準備今日建議' : '尚未取得 AI 建議')),
        subtitle: Text(_advice?.advice ?? (_error ?? '將依今日餐點、步數、運動與減重計畫產生建議。')),
      )),
      const SizedBox(height: 22),
      Row(children: [Expanded(child: Text('今天的餐點', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), TextButton.icon(onPressed: widget.onOpenMealLog, icon: const Icon(Icons.add), label: const Text('新增'))]),
      if (meals.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Icon(Icons.restaurant_outlined, size: 36), const SizedBox(height: 8), const Text('尚未記錄任何餐點'), const SizedBox(height: 10), OutlinedButton(onPressed: widget.onOpenMealLog, child: const Text('開始記錄'))]))) else ...meals.map((meal) => _MealTile(meal: meal)),
    ]);
  }

  Future<void> _loadAdvice(DietController diet, List<MealEntry> meals, int calories, double protein, {bool force = false}) async {
    if (_loading || (!force && _signature == null)) return;
    setState(() { _loading = true; _error = null; });
    try {
      final advice = await AiService().createDailyAdvice(
        meals: meals.isEmpty ? '尚未記錄餐點' : meals.map((meal) => '${meal.mealType}：${meal.name}（${meal.calories} kcal，蛋白質 ${meal.protein.toStringAsFixed(0)} g）').join('；'),
        caloriesConsumed: calories, calorieTarget: diet.calorieTarget, proteinConsumed: protein, proteinTarget: diet.proteinTarget,
        steps: diet.totalStepsToday, exerciseMinutes: diet.totalExerciseMinutesToday, exerciseType: diet.exerciseType,
        activeCalories: diet.estimatedActivityCalories, activeCaloriesTarget: diet.activeCalorieTarget, goalWeight: diet.weightTarget,
      );
      if (mounted) setState(() => _advice = advice);
    } catch (error) {
      if (mounted) setState(() => _error = error is AiServiceException ? error.message : '無法取得 AI 建議，請檢查網路與 AI 服務設定。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static double _progress(num value, num target) => target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble();
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.title, required this.progress, required this.value, required this.color});
  final String title; final double progress; final String value; final Color color;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), LinearProgressIndicator(value: progress, color: color)])));
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal}); final MealEntry meal;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: CircleAvatar(child: Icon(_iconFor(meal.mealType))), title: Text(meal.name), subtitle: Text(meal.mealType), trailing: Text('${meal.calories} kcal\n${meal.protein.toStringAsFixed(0)} g', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))));
  IconData _iconFor(String type) => switch (type) { '早餐' => Icons.free_breakfast_outlined, '午餐' => Icons.lunch_dining_outlined, '晚餐' => Icons.dinner_dining_outlined, _ => Icons.cookie_outlined };
}
