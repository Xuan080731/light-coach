import 'package:flutter/material.dart';

import '../../services/health_connect_service.dart';
import '../../state/diet_controller.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});
  static const exerciseTypes = ['散步', '快走', '慢跑', '跑步', '單車', '重訓', '游泳', '瑜伽／伸展', '有氧舞蹈', '球類運動', '間歇訓練'];

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('活動與步數')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('今日活動', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.directions_walk_outlined), title: const Text('步數'), trailing: Text('${diet.totalStepsToday} 步')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.timer_outlined), title: Text(diet.exerciseType), subtitle: const Text('手動運動'), trailing: Text('${diet.totalExerciseMinutesToday} 分鐘')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.local_fire_department_outlined), title: const Text('今日活動消耗'), subtitle: Text(diet.hasHealthSyncToday ? '已同步 Health Connect；未同步部分採手動估算。' : '依步數與運動時間估算。'), trailing: Text('${diet.estimatedActivityCalories} kcal')),
        ])),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () => _syncHealth(context, diet), icon: const Icon(Icons.sync), label: const Text('同步 Google Health Connect')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _editManualActivity(context, diet), icon: const Icon(Icons.edit_outlined), label: const Text('手動輸入步數與運動')),
        const SizedBox(height: 24),
        Text('減重計畫消耗目標', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('AI 計畫目標：${diet.activeCalorieTarget} kcal／日；目前 ${diet.estimatedActivityCalories} kcal。'),
      ]),
    );
  }

  Future<void> _syncHealth(BuildContext context, DietController diet) async {
    try {
      final snapshot = await HealthConnectService().syncToday();
      await diet.updateHealthActivity(steps: snapshot.steps, activeCalories: snapshot.activeCalories);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已同步今日步數與活動熱量。')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is HealthConnectException ? error.message : '無法同步 Health Connect，請確認已安裝並授權。')));
    }
  }

  Future<void> _editManualActivity(BuildContext context, DietController diet) async {
    final steps = TextEditingController(text: diet.manualSteps.toString());
    final minutes = TextEditingController(text: diet.exerciseMinutes.toString());
    var type = diet.exerciseType;
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('手動活動紀錄'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: steps, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '今日步數', border: OutlineInputBorder())), const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: '運動項目', border: OutlineInputBorder()), items: exerciseTypes.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setDialogState(() => type = value!)), const SizedBox(height: 12),
        TextField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '運動時間（分鐘）', border: OutlineInputBorder())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('儲存'))],
    )));
    final stepCount = int.tryParse(steps.text); final minuteCount = int.tryParse(minutes.text);
    if (saved == true && stepCount != null && stepCount >= 0 && minuteCount != null && minuteCount >= 0) await diet.updateManualActivity(steps: stepCount, minutes: minuteCount, type: type);
    steps.dispose(); minutes.dispose();
  }
}
