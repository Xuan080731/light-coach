import 'package:flutter/material.dart';

import '../../services/ai_service.dart';
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            const SizedBox(height: 6),
            Text('身體數值',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('體重、BMI 與減重目標會共同影響你的 AI 計畫。'),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
              child: Column(
                children: [
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.monitor_weight_outlined),
                      title: const Text('最新體重'),
                      trailing: Text(latest == null
                          ? '尚未記錄'
                          : '${latest.toStringAsFixed(1)} kg')),
                  const Divider(height: 1),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.analytics_outlined),
                      title: const Text('BMI'),
                      subtitle:
                          Text(bmi == null ? '新增體重與身高後計算' : _bmiLabel(bmi)),
                      trailing: Text(bmi?.toStringAsFixed(1) ?? '—')),
                  const Divider(height: 1),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('目標體重'),
                      trailing:
                          Text('${diet.weightTarget.toStringAsFixed(1)} kg')),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: () => _editBodyProfile(context, diet),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('編輯身體資料')),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('身體數值紀錄',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (diet.weights.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('尚無體重紀錄。'),
                ),
              )
            else
              ...diet.weights.map((entry) => _WeightRow(entry: entry)),
            const SizedBox(height: 24),
            Text('用 AI 建立目標',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('AI 會依 BMI 與身體資料建議漸進式目標，並規劃每日熱量、蛋白質及活動消耗目標。結果可先檢視再套用。'),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: diet.currentWeight == null
                    ? null
                    : () => _requestPlan(context, diet),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('讓 AI 建議減重目標')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: diet.currentWeight == null
                    ? null
                    : () => _askDesiredWeight(context, diet),
                icon: const Icon(Icons.tune),
                label: const Text('設定目標體重後由 AI 規劃')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWeight(context, diet),
        icon: const Icon(Icons.add_chart),
        label: const Text('記錄體重'),
      ),
    );
  }

  String _bmiLabel(double bmi) => bmi < 18.5
      ? '偏輕'
      : bmi < 24
          ? '一般範圍'
          : bmi < 27
              ? '過重'
              : '肥胖風險較高';
  Future<void> _showAddWeight(BuildContext context, DietController diet) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('記錄體重'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: '體重（kg）', border: OutlineInputBorder())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('儲存'))
                ]));
    final kilograms = double.tryParse(controller.text);
    controller.dispose();
    if (saved == true && kilograms != null && kilograms > 0 && kilograms < 500)
      await diet.addWeight(kilograms);
  }

  Future<void> _editBodyProfile(
      BuildContext context, DietController diet) async {
    final height =
        TextEditingController(text: diet.heightCm.toStringAsFixed(0));
    final age = TextEditingController(text: diet.age.toString());
    var sex = diet.biologicalSex;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('身體資料'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: height,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '身高（cm）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '年齡',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: sex,
                decoration: const InputDecoration(
                  labelText: '生理性別（供基礎代謝估算）',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('女性')),
                  DropdownMenuItem(value: 'male', child: Text('男性')),
                ],
                onChanged: (value) => setDialogState(() => sex = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    final heightValue = double.tryParse(height.text);
    final ageValue = int.tryParse(age.text);
    height.dispose();
    age.dispose();
    if (saved == true &&
        heightValue != null &&
        heightValue >= 100 &&
        heightValue <= 250 &&
        ageValue != null &&
        ageValue >= 13 &&
        ageValue <= 120) {
      await diet.updateBodyProfile(
          height: heightValue, profileAge: ageValue, sex: sex);
    }
  }

  Future<void> _askDesiredWeight(
      BuildContext context, DietController diet) async {
    final controller =
        TextEditingController(text: diet.weightTarget.toStringAsFixed(1));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('設定目標體重'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '目標體重（kg）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('請 AI 規劃'),
          )
        ],
      ),
    );
    final desired = double.tryParse(controller.text);
    controller.dispose();
    if (accepted == true &&
        desired != null &&
        desired >= 35 &&
        desired < diet.currentWeight!) {
      await _requestPlan(context, diet, desiredWeight: desired);
    }
  }

  Future<void> _requestPlan(BuildContext context, DietController diet,
      {double? desiredWeight}) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Row(children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('AI 正在建立你的減重計畫…'))
          ]),
        ),
      ),
    );
    try {
      final plan = await AiService().createWeightPlan(
        currentWeight: diet.currentWeight!,
        heightCm: diet.heightCm,
        age: diet.age,
        sex: diet.biologicalSex,
        bmi: diet.bmi!,
        desiredWeight: desiredWeight,
      );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final apply = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('AI 減重計畫'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.summary),
              const SizedBox(height: 14),
              Text('目標體重：${plan.goalWeight.toStringAsFixed(1)} kg'),
              Text('每週減重：${plan.weeklyLossKg.toStringAsFixed(1)} kg'),
              Text('每日熱量：${plan.dailyCalories} kcal'),
              Text('每日蛋白質：${plan.proteinGrams.toStringAsFixed(0)} g'),
              Text('每日運動額外消耗：${plan.activeCalories} kcal'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('套用計畫'),
            )
          ],
        ),
      );
      if (apply == true) {
        await diet.applyAiPlan(
          goalWeight: plan.goalWeight,
          weeklyLoss: plan.weeklyLossKg,
          calories: plan.dailyCalories,
          protein: plan.proteinGrams,
          activeCalories: plan.activeCalories,
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is AiServiceException
            ? error.message
            : 'AI 計畫建立失敗，請檢查網路與 AI 設定。'),
      ));
    }
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.entry});
  final WeightEntry entry;
  @override
  Widget build(BuildContext context) {
    final d = entry.loggedAt;
    return Card(
        child: ListTile(
            leading:
                const CircleAvatar(child: Icon(Icons.monitor_weight_outlined)),
            title: Text('${entry.kilograms.toStringAsFixed(1)} kg'),
            subtitle: Text(
                '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}')));
  }
}
