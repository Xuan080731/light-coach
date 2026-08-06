import 'package:flutter/material.dart';

import '../../features/goals/ai_goal_plan_page.dart';
import '../../models/diet_models.dart';
import '../../state/diet_controller.dart';

class WeightPage extends StatelessWidget {
  const WeightPage({super.key});

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    final latest = diet.currentWeight;
    final bmi = diet.bmi;
    return Scaffold(
      appBar: AppBar(title: const Text('身體數值')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 100), children: [
        Text('身體', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6), const Text('體重、BMI 與減重目標會共同影響你的 AI 計畫。'), const SizedBox(height: 16),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.monitor_weight_outlined), title: const Text('最新體重'), trailing: Text(latest == null ? '尚未記錄' : '${latest.toStringAsFixed(1)} kg')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.analytics_outlined), title: const Text('BMI'), subtitle: Text(bmi == null ? '新增體重與身高後計算' : _bmiLabel(bmi)), trailing: Text(bmi?.toStringAsFixed(1) ?? '—')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('目標體重'), trailing: Text('${diet.weightTarget.toStringAsFixed(1)} kg')),
        ])),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiGoalPlanPage())), icon: const Icon(Icons.auto_awesome_outlined), label: const Text('BMI 與 AI 減重計畫')),
        const SizedBox(height: 24),
        Text('身體數值紀錄', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        if (diet.weights.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('尚無體重紀錄。')))
        else ...diet.weights.map((entry) => _WeightRow(entry: entry)),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showAddWeight(context, diet), icon: const Icon(Icons.add_chart), label: const Text('記錄體重')),
    );
  }
  String _bmiLabel(double bmi) => bmi < 18.5 ? '偏輕' : bmi < 24 ? '一般範圍' : bmi < 27 ? '過重' : '肥胖風險較高';
  Future<void> _showAddWeight(BuildContext context, DietController diet) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('記錄體重'), content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '體重（kg）', border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('儲存'))]));
    final kilograms = double.tryParse(controller.text); controller.dispose();
    if (saved == true && kilograms != null && kilograms > 0 && kilograms < 500) await diet.addWeight(kilograms);
  }
}
class _WeightRow extends StatelessWidget { const _WeightRow({required this.entry}); final WeightEntry entry; @override Widget build(BuildContext context) { final d = entry.loggedAt; return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.monitor_weight_outlined)), title: Text('${entry.kilograms.toStringAsFixed(1)} kg'), subtitle: Text('${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}'))); } }
