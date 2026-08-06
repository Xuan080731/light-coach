import 'package:flutter/material.dart';

import '../../models/diet_models.dart';
import '../../state/diet_controller.dart';

class WeightPage extends StatelessWidget {
  const WeightPage({super.key});

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    final weights = diet.weights;
    final latest = weights.isEmpty ? null : weights.first;
    final difference = latest == null ? null : latest.kilograms - diet.weightTarget;
    return Scaffold(
      appBar: AppBar(title: const Text('體重紀錄')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 100), children: [
        Text('追蹤長期趨勢', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4), const Text('建議在相同時段、相近條件下量測。'), const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('最新體重', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6),
          Text(latest == null ? '尚未記錄' : '${latest.kilograms.toStringAsFixed(1)} kg', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(latest == null ? '新增第一次量測，開始累積你的趨勢。' : '距離 ${diet.weightTarget.toStringAsFixed(1)} kg 目標 ${difference! >= 0 ? '還有 ${difference.toStringAsFixed(1)} kg' : '已低於 ${(difference.abs()).toStringAsFixed(1)} kg'}'),
        ]))),
        const SizedBox(height: 22),
        Text('歷史紀錄', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        if (weights.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('尚無體重紀錄。')))
        else ...weights.map((entry) => _WeightRow(entry: entry)),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showAddWeight(context, diet), icon: const Icon(Icons.add_chart), label: const Text('記錄體重')),
    );
  }

  Future<void> _showAddWeight(BuildContext context, DietController diet) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('記錄體重'),
      content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '體重（kg）', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('儲存'))],
    ));
    final kilograms = double.tryParse(controller.text);
    if (saved == true && kilograms != null && kilograms > 0 && kilograms < 500) await diet.addWeight(kilograms);
    controller.dispose();
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.entry}); final WeightEntry entry;
  @override
  Widget build(BuildContext context) {
    final d = entry.loggedAt;
    return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.monitor_weight_outlined)), title: Text('${entry.kilograms.toStringAsFixed(1)} kg'), subtitle: Text('${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}')));
  }
}
