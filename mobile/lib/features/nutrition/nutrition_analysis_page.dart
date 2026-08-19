import 'package:flutter/material.dart';

import '../../services/nutrition_score_service.dart';
import '../../state/diet_controller.dart';

class NutritionAnalysisPage extends StatelessWidget {
  const NutritionAnalysisPage({super.key, required this.aiSummary});

  final String aiSummary;

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    final today = DateTime.now();
    final calories = diet.caloriesFor(today);
    final protein = diet.proteinFor(today);
    final carbs = diet.carbsFor(today);
    final fat = diet.fatFor(today);
    final fiber = diet.fiberFor(today);
    final score = const NutritionScoreService().calculate(
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
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          title: const Text('今日營養分析',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(
            color: color.primary.withValues(
                alpha: Theme.of(context).brightness == Brightness.light
                    ? 0.10
                    : 0.18),
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Container(
                      width: 78,
                      height: 78,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: color.primaryContainer,
                          shape: BoxShape.circle),
                      child: Text('${score.totalScore}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('今日營養分數',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${score.totalScore} / 100'),
                        const SizedBox(height: 8),
                        const Text('分數由程式依今日攝取與目標計算；AI 只提供調整建議。'),
                      ]))
                ]))),
        const SizedBox(height: 14),
        Text('營養進度',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _NutritionProgress(
            label: '熱量',
            value: calories.toDouble(),
            target: diet.calorieTarget.toDouble(),
            unit: 'kcal',
            color: color.primary),
        _NutritionProgress(
            label: '蛋白質',
            value: protein,
            target: diet.proteinTarget,
            unit: 'g',
            color: color.secondary),
        _NutritionProgress(
            label: '碳水化合物',
            value: carbs,
            target: diet.carbsTarget,
            unit: 'g',
            color: color.tertiary),
        _NutritionProgress(
            label: '脂肪',
            value: fat,
            target: diet.fatTarget,
            unit: 'g',
            color: color.error),
        _NutritionProgress(
            label: '膳食纖維',
            value: fiber,
            target: diet.fiberTarget,
            unit: 'g',
            color: color.primary),
        const SizedBox(height: 14),
        Text('分數明細',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
            child: Column(children: [
          _ScoreRow(label: '熱量達成', value: score.calorieScore, max: 30),
          const Divider(height: 1),
          _ScoreRow(label: '蛋白質', value: score.proteinScore, max: 25),
          const Divider(height: 1),
          _ScoreRow(label: '碳水化合物', value: score.carbsScore, max: 15),
          const Divider(height: 1),
          _ScoreRow(label: '脂肪', value: score.fatScore, max: 15),
          const Divider(height: 1),
          _ScoreRow(label: '膳食纖維', value: score.fiberScore, max: 15),
        ])),
        const SizedBox(height: 14),
        Text('AI 摘要',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16), child: Text(aiSummary))),
      ]),
    );
  }
}

class _NutritionProgress extends StatelessWidget {
  const _NutritionProgress({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
  });

  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final exceeded = target > 0 && value > target;
    final valueText =
        unit == 'kcal' ? value.round().toString() : value.toStringAsFixed(0);
    final targetText =
        unit == 'kcal' ? target.round().toString() : target.toStringAsFixed(0);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(label,
                        style: Theme.of(context).textTheme.titleMedium)),
                if (exceeded)
                  Text('已超過目標',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 6),
              Text('$valueText / $targetText $unit',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value:
                      target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble(),
                  color: color),
            ])));
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(
      {required this.label, required this.value, required this.max});

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) => ListTile(
      dense: true, title: Text(label), trailing: Text('$value / $max'));
}
