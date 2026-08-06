import 'package:flutter/material.dart';

import '../../models/diet_models.dart';
import '../../state/diet_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpenMealLog});

  final VoidCallback onOpenMealLog;

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    final color = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final calories = diet.caloriesFor(today);
    final protein = diet.proteinFor(today);
    final meals = diet.mealsFor(today);
    final remaining = diet.calorieTarget - calories;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          '今天，照顧好自己',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('記下每一餐，讓目標變得清楚。', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 22),
        Card(
          color: color.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日熱量', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '$calories / ${diet.calorieTarget} kcal',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: color.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                    value: _progress(calories, diet.calorieTarget)),
                const SizedBox(height: 8),
                Text(remaining >= 0
                    ? '還可攝取 $remaining kcal'
                    : '已超過目標 ${-remaining} kcal'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ProgressCard(
          title: '蛋白質',
          progress: _progress(protein, diet.proteinTarget),
          value:
              '${protein.toStringAsFixed(0)} / ${diet.proteinTarget.toStringAsFixed(0)} g',
          color: color.secondary,
        ),
        const SizedBox(height: 22),
        Text('今日建議',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.secondaryContainer,
              child: const Icon(Icons.auto_awesome),
            ),
            title: Text(_adviceTitle(remaining, protein, diet.proteinTarget)),
            subtitle: Text(_adviceBody(remaining, protein, diet.proteinTarget)),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                '今天的餐點',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: onOpenMealLog,
              icon: const Icon(Icons.add),
              label: const Text('新增'),
            ),
          ],
        ),
        if (meals.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.restaurant_outlined, size: 36),
                  const SizedBox(height: 8),
                  const Text('尚未記錄任何餐點'),
                  const SizedBox(height: 10),
                  OutlinedButton(
                      onPressed: onOpenMealLog, child: const Text('開始記錄')),
                ],
              ),
            ),
          )
        else
          ...meals.map((meal) => _MealTile(meal: meal)),
      ],
    );
  }

  static double _progress(num value, num target) =>
      target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble();
  static String _adviceTitle(int remaining, double protein, double target) {
    if (remaining < 0) return '今天的熱量已超過目標';
    if (target - protein > 20) return '蛋白質還可以再補一些';
    return '進度很穩定，繼續保持';
  }

  static String _adviceBody(int remaining, double protein, double target) {
    if (remaining < 0) return '下一餐可選擇蔬菜、豆製品或清湯等較清爽的食物。';
    if (target - protein > 20) return '可考慮加入豆腐、雞蛋、魚肉或無糖優格。';
    return '均衡飲食、充足喝水與規律作息都很重要。';
  }
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
            LinearProgressIndicator(value: progress, color: color),
          ])));
}

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
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ));
  IconData _iconFor(String type) => switch (type) {
        '早餐' => Icons.free_breakfast_outlined,
        '午餐' => Icons.lunch_dining_outlined,
        '晚餐' => Icons.dinner_dining_outlined,
        _ => Icons.cookie_outlined
      };
}
