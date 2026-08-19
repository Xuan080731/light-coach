import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/diet_models.dart';
import '../../services/ai_service.dart';
import '../../state/diet_controller.dart';

class MealLogPage extends StatefulWidget {
  const MealLogPage({super.key});

  @override
  State<MealLogPage> createState() => _MealLogPageState();
}

class _MealLogPageState extends State<MealLogPage> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    final meals = diet.mealsFor(_selectedDate);
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    return Scaffold(
      appBar: AppBar(
          title:
              const Text('飲食紀錄', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                tooltip: '以 AI 分析餐點照片',
                onPressed: isToday ? () => _analyzePhoto(context, diet) : null,
                icon: const Icon(Icons.auto_awesome)),
            IconButton(
                tooltip: '選擇日期',
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined))
          ]),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            if (isToday)
              _AiPhotoCard(onAnalyze: () => _analyzePhoto(context, diet)),
            const SizedBox(height: 22),
            Text(isToday ? '今天吃了什麼？' : '${_formatDate(_selectedDate)} 的餐點',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(isToday ? '點選餐點可修改名稱、餐別與所有營養數值。' : '可查看或修改當日已記錄的餐點。'),
            const SizedBox(height: 12),
            if (meals.isEmpty && isToday)
              _EmptyMeals(onAdd: () => _showMealEditor(context, diet))
            else if (meals.isEmpty)
              const _EmptyHistoryMeals()
            else
              ...meals.map((meal) => _MealRow(
                  meal: meal,
                  onEdit: () => _showMealEditor(context, diet, existing: meal),
                  onDelete: () => diet.removeMeal(meal.id))),
          ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: isToday ? () => _showMealEditor(context, diet) : null,
          icon: const Icon(Icons.add),
          label: const Text('手動新增')),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (selected != null && mounted) setState(() => _selectedDate = selected);
  }

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  Future<void> _analyzePhoto(BuildContext context, DietController diet) async {
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('拍攝餐點'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('從相簿選擇'),
                  onTap: () =>
                      Navigator.pop(sheetContext, ImageSource.gallery)),
            ])));
    if (source == null || !context.mounted) return;
    var progressVisible = false;
    try {
      final image = await ImagePicker()
          .pickImage(source: source, maxWidth: 1800, imageQuality: 82);
      if (image == null || !context.mounted) return;
      showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => WillPopScope(
              onWillPop: () async => false,
              child: const AlertDialog(
                  content: Row(children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('正在由 AI 分析餐點照片…'))
              ]))));
      progressVisible = true;
      final result = await AiService().analyzeImage(
          imageBytes: await image.readAsBytes(),
          mimeType: image.mimeType ?? 'image/jpeg');
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressVisible = false;
      await _showMealEditor(context, diet,
          initialName: result.suggestedName,
          initialCalories: result.totalCalories,
          initialProtein: result.totalProtein,
          initialCarbs: result.totalCarbs,
          initialFat: result.totalFat,
          initialFiber: result.totalFiber,
          initialPortionGrams: result.totalPortionGrams,
          analysisNote: result.notes,
          confidence: result.confidence);
    } catch (error) {
      if (!context.mounted) return;
      if (progressVisible) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is AiServiceException
              ? error.message
              : '無法完成 AI 分析，請檢查網路與 AI 設定。')));
    }
  }

  Future<void> _showMealEditor(BuildContext context, DietController diet,
      {MealEntry? existing,
      String initialName = '',
      int? initialCalories,
      double? initialProtein,
      double? initialCarbs,
      double? initialFat,
      double? initialFiber,
      double? initialPortionGrams,
      String? analysisNote,
      double? confidence}) async {
    final name = TextEditingController(text: existing?.name ?? initialName);
    final calories = TextEditingController(
        text:
            existing?.calories.toString() ?? initialCalories?.toString() ?? '');
    final protein = TextEditingController(
        text: existing?.protein.toStringAsFixed(0) ??
            initialProtein?.toStringAsFixed(0) ??
            '');
    final carbs = TextEditingController(
        text: existing?.carbs.toStringAsFixed(0) ??
            initialCarbs?.toStringAsFixed(0) ??
            '0');
    final fat = TextEditingController(
        text: existing?.fat.toStringAsFixed(0) ??
            initialFat?.toStringAsFixed(0) ??
            '0');
    final fiber = TextEditingController(
        text: existing?.fiber.toStringAsFixed(0) ??
            initialFiber?.toStringAsFixed(0) ??
            '0');
    final portion = TextEditingController(
        text: existing?.portionGrams?.toStringAsFixed(0) ??
            initialPortionGrams?.toStringAsFixed(0) ??
            '');
    var mealType = existing?.mealType ?? '午餐';
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text(existing == null
                      ? (analysisNote == null ? '新增餐點' : '確認 AI 分析結果')
                      : '編輯餐點'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (analysisNote != null)
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(
                              'AI 信心 ${(confidence! * 100).round()}%\n$analysisNote')),
                    if (analysisNote != null) const SizedBox(height: 12),
                    TextField(
                        controller: name,
                        decoration: const InputDecoration(
                            labelText: '餐點名稱', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        value: mealType,
                        decoration: const InputDecoration(
                            labelText: '餐別', border: OutlineInputBorder()),
                        items: const ['早餐', '午餐', '晚餐', '點心']
                            .map((type) => DropdownMenuItem(
                                value: type, child: Text(type)))
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => mealType = value!)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: calories,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: '熱量（kcal）',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: protein,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: '蛋白質（g）', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: carbs,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: '碳水化合物（g）',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: fat,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: '脂肪（g）', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: fiber,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: '膳食纖維（g）',
                            border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                        controller: portion,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: '估計份量（g，可留空）',
                            border: OutlineInputBorder())),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(existing == null ? '儲存餐點' : '儲存變更'))
                  ],
                )));
    final calorieValue = int.tryParse(calories.text);
    final proteinValue = double.tryParse(protein.text);
    final carbsValue = double.tryParse(carbs.text);
    final fatValue = double.tryParse(fat.text);
    final fiberValue = double.tryParse(fiber.text);
    final portionValue =
        portion.text.trim().isEmpty ? null : double.tryParse(portion.text);
    if (saved == true &&
        name.text.trim().isNotEmpty &&
        calorieValue != null &&
        calorieValue >= 0 &&
        proteinValue != null &&
        proteinValue >= 0 &&
        carbsValue != null &&
        carbsValue >= 0 &&
        fatValue != null &&
        fatValue >= 0 &&
        fiberValue != null &&
        fiberValue >= 0 &&
        (portionValue == null || portionValue >= 0)) {
      if (existing == null)
        await diet.addMeal(
            name: name.text,
            mealType: mealType,
            calories: calorieValue,
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue,
            fiber: fiberValue,
            portionGrams: portionValue);
      else
        await diet.updateMeal(
            id: existing.id,
            name: name.text,
            mealType: mealType,
            calories: calorieValue,
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue,
            fiber: fiberValue,
            portionGrams: portionValue);
    } else if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請填寫有效且非負的餐點名稱與營養數值。')));
    }
    // Dialog routes finish their exit transition after `showDialog` completes.
    // Keep the controllers alive until that transition has released its fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
    fiber.dispose();
    portion.dispose();
  }
}

class _AiPhotoCard extends StatelessWidget {
  const _AiPhotoCard({required this.onAnalyze});
  final VoidCallback onAnalyze;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            CircleAvatar(
                radius: 25,
                child: Icon(Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('AI 餐點辨識',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  const Text('拍照後由你選擇的 AI 分析食物與營養。')
                ])),
            IconButton.filledTonal(
                onPressed: onAnalyze,
                icon: const Icon(Icons.camera_alt_outlined))
          ])));
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Icon(Icons.restaurant_outlined, size: 42),
            const SizedBox(height: 12),
            const Text('尚未記錄任何餐點'),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onAdd, child: const Text('手動新增餐點'))
          ])));
}

class _EmptyHistoryMeals extends StatelessWidget {
  const _EmptyHistoryMeals();

  @override
  Widget build(BuildContext context) => const Card(
      child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [
            Icon(Icons.history_toggle_off_outlined, size: 42),
            SizedBox(height: 12),
            Text('這一天尚未記錄餐點'),
          ])));
}

class _MealRow extends StatelessWidget {
  const _MealRow(
      {required this.meal, required this.onEdit, required this.onDelete});
  final MealEntry meal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          onTap: onEdit,
          isThreeLine: true,
          leading: const CircleAvatar(child: Icon(Icons.restaurant_menu)),
          title: Text(meal.name),
          subtitle: Text(
              '${meal.mealType} · 蛋白 ${meal.protein.toStringAsFixed(0)} g · 碳水 ${meal.carbs.toStringAsFixed(0)} g\n脂肪 ${meal.fat.toStringAsFixed(0)} g · 纖維 ${meal.fiber.toStringAsFixed(0)} g'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${meal.calories}\nkcal',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
                tooltip: '編輯餐點',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined)),
            IconButton(
                tooltip: '刪除餐點',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline))
          ])));
}
