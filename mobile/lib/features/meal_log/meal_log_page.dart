import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/diet_models.dart';
import '../../services/ai_service.dart';
import '../../state/diet_controller.dart';

class MealLogPage extends StatelessWidget {
  const MealLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    final meals = diet.mealsFor(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('飲食紀錄'),
        actions: [IconButton(tooltip: '以 AI 分析餐點照片', onPressed: () => _analyzePhoto(context, diet), icon: const Icon(Icons.auto_awesome))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 100), children: [
        _AiPhotoCard(onAnalyze: () => _analyzePhoto(context, diet)),
        const SizedBox(height: 22),
        Text('今天吃了什麼？', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4), const Text('AI 分析結果可在儲存前自行修改。'), const SizedBox(height: 12),
        if (meals.isEmpty) _EmptyMeals(onAdd: () => _showAddMeal(context, diet)) else ...meals.map((meal) => _MealRow(meal: meal, onDelete: () => diet.removeMeal(meal.id))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showAddMeal(context, diet), icon: const Icon(Icons.add), label: const Text('手動新增')),
    );
  }

  Future<void> _analyzePhoto(BuildContext context, DietController diet) async {
    var showingProgress = false;
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (sheetContext) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('拍攝餐點'), onTap: () => Navigator.pop(sheetContext, ImageSource.camera)),
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('從相簿選擇'), onTap: () => Navigator.pop(sheetContext, ImageSource.gallery)),
    ])));
    if (source == null || !context.mounted) return;
    try {
      final image = await ImagePicker().pickImage(source: source, maxWidth: 1800, imageQuality: 82);
      if (image == null || !context.mounted) return;
      showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const PopScope(canPop: false, child: AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Expanded(child: Text('正在由 AI 分析餐點照片…'))]))));
      showingProgress = true;
      final analysis = await AiService().analyzeImage(imageBytes: await image.readAsBytes(), mimeType: image.mimeType ?? 'image/jpeg');
      if (!context.mounted) return;
      if (showingProgress) Navigator.of(context, rootNavigator: true).pop();
      showingProgress = false;
      await _showAddMeal(context, diet, initialName: analysis.suggestedName, initialCalories: analysis.totalCalories, initialProtein: analysis.totalProtein, analysisNote: analysis.notes, confidence: analysis.confidence);
    } catch (error) {
      if (!context.mounted) return;
      if (showingProgress) Navigator.of(context, rootNavigator: true).pop();
      final message = error is AiServiceException ? error.message : '無法完成 AI 分析，請檢查網路與供應商設定。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 5)));
    }
  }

  Future<void> _showAddMeal(BuildContext context, DietController diet, {String initialName = '', int? initialCalories, double? initialProtein, String? analysisNote, double? confidence}) async {
    final name = TextEditingController(text: initialName);
    final calories = TextEditingController(text: initialCalories?.toString() ?? '');
    final protein = TextEditingController(text: initialProtein?.toStringAsFixed(0) ?? '');
    var mealType = '午餐';
    final added = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(analysisNote == null ? '新增餐點' : '確認 AI 分析結果'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (analysisNote != null) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)), child: Text('AI 信心 ${(confidence! * 100).round()}%\n$analysisNote')),
        if (analysisNote != null) const SizedBox(height: 12),
        TextField(controller: name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: '餐點名稱', hintText: '例如：雞胸肉便當', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: mealType, decoration: const InputDecoration(labelText: '餐別', border: OutlineInputBorder()), items: const ['早餐', '午餐', '晚餐', '點心'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(), onChanged: (value) => setDialogState(() => mealType = value!)),
        const SizedBox(height: 12),
        TextField(controller: calories, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '熱量（kcal）', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: protein, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '蛋白質（g）', border: OutlineInputBorder())),
        if (analysisNote == null) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () {
          final estimate = _estimate(name.text);
          calories.text = estimate.$1.toString(); protein.text = estimate.$2.toStringAsFixed(0);
        }, icon: const Icon(Icons.auto_awesome_outlined), label: const Text('依餐點名稱帶入估算值'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('儲存餐點'))],
    )));
    final kcal = int.tryParse(calories.text); final proteinGrams = double.tryParse(protein.text);
    if (added == true && name.text.trim().isNotEmpty && kcal != null && kcal >= 0 && proteinGrams != null && proteinGrams >= 0) {
      await diet.addMeal(name: name.text, mealType: mealType, calories: kcal, protein: proteinGrams);
    } else if (added == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請填寫有效的餐點名稱、熱量與蛋白質。')));
    }
    name.dispose(); calories.dispose(); protein.dispose();
  }

  (int, double) _estimate(String value) {
    final text = value.toLowerCase();
    if (text.contains('雞') || text.contains('魚') || text.contains('牛') || text.contains('便當')) return (550, 35);
    if (text.contains('沙拉')) return (280, 15);
    if (text.contains('麵') || text.contains('飯')) return (500, 14);
    if (text.contains('蛋') || text.contains('豆腐')) return (220, 16);
    return (350, 12);
  }
}

class _AiPhotoCard extends StatelessWidget {
  const _AiPhotoCard({required this.onAnalyze}); final VoidCallback onAnalyze;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
    CircleAvatar(radius: 25, child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary)), const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('AI 餐點辨識', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 3), const Text('拍照後由你選擇的 AI 分析食物與營養。')])) ,
    IconButton.filledTonal(onPressed: onAnalyze, icon: const Icon(Icons.camera_alt_outlined), tooltip: '分析餐點照片'),
  ])));
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals({required this.onAdd}); final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    const Icon(Icons.restaurant_outlined, size: 42), const SizedBox(height: 12), Text('尚未記錄任何餐點', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10), OutlinedButton(onPressed: onAdd, child: const Text('手動新增餐點')),
  ])));
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.onDelete}); final MealEntry meal; final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: const CircleAvatar(child: Icon(Icons.restaurant_menu)), title: Text(meal.name), subtitle: Text('${meal.mealType} · 蛋白質 ${meal.protein.toStringAsFixed(0)} g'),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('${meal.calories}\nkcal', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(tooltip: '刪除餐點', onPressed: onDelete, icon: const Icon(Icons.delete_outline))]),
  ));
}
