import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diet_models.dart';

class DietController extends ChangeNotifier {
  static const _storageKey = 'diet_coach_data_v2';

  List<MealEntry> _meals = [];
  List<WeightEntry> _weights = [];
  int calorieTarget = 1800;
  double proteinTarget = 90;
  double weightTarget = 65;
  int activeCalorieTarget = 300;
  double weeklyLossKg = 0.3;
  double heightCm = 165;
  int age = 30;
  String biologicalSex = 'female';
  int manualSteps = 0;
  int exerciseMinutes = 0;
  String exerciseType = '快走';
  int syncedSteps = 0;
  int syncedActiveCalories = 0;
  String activityDate = '';

  List<MealEntry> get meals => List.unmodifiable(_meals);
  List<WeightEntry> get weights => List.unmodifiable(_weights);
  double? get currentWeight =>
      _weights.isEmpty ? null : _weights.first.kilograms;
  double? get bmi => currentWeight == null || heightCm <= 0
      ? null
      : currentWeight! / ((heightCm / 100) * (heightCm / 100));
  int get totalStepsToday => _isTodayActivity
      ? [manualSteps, syncedSteps].reduce((a, b) => a > b ? a : b)
      : 0;
  int get totalExerciseMinutesToday => _isTodayActivity ? exerciseMinutes : 0;
  int get estimatedActivityCalories {
    if (!_isTodayActivity) return 0;
    final manualEstimate =
        (manualSteps * 0.04 + exerciseMinutes * exerciseCaloriesPerMinute)
            .round();
    return syncedActiveCalories > manualEstimate
        ? syncedActiveCalories
        : manualEstimate;
  }

  bool get hasHealthSyncToday =>
      _isTodayActivity && (syncedSteps > 0 || syncedActiveCalories > 0);
  int get estimatedBmr {
    final weight = currentWeight ?? weightTarget;
    final base = 10 * weight + 6.25 * heightCm - 5 * age;
    return (base + (biologicalSex == 'male' ? 5 : -161)).round();
  }

  int get estimatedTotalBurned => estimatedBmr + estimatedActivityCalories;
  bool get _isTodayActivity => activityDate == _dateKey(DateTime.now());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(_storageKey) ?? prefs.getString('diet_coach_data_v1');
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _meals = (data['meals'] as List<dynamic>? ?? [])
          .map((item) => MealEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      _weights = (data['weights'] as List<dynamic>? ?? [])
          .map((item) => WeightEntry.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      calorieTarget = (data['calorieTarget'] as num? ?? 1800).round();
      proteinTarget = (data['proteinTarget'] as num? ?? 90).toDouble();
      weightTarget = (data['weightTarget'] as num? ?? 65).toDouble();
      activeCalorieTarget =
          (data['activeCalorieTarget'] as num? ?? 300).round();
      weeklyLossKg = (data['weeklyLossKg'] as num? ?? 0.3).toDouble();
      heightCm = (data['heightCm'] as num? ?? 165).toDouble();
      age = (data['age'] as num? ?? 30).round();
      biologicalSex = data['biologicalSex'] as String? ?? 'female';
      manualSteps = (data['manualSteps'] as num? ?? 0).round();
      exerciseMinutes = (data['exerciseMinutes'] as num? ?? 0).round();
      exerciseType = data['exerciseType'] as String? ?? '快走';
      syncedSteps = (data['syncedSteps'] as num? ?? 0).round();
      syncedActiveCalories =
          (data['syncedActiveCalories'] as num? ?? 0).round();
      activityDate = data['activityDate'] as String? ?? '';
      notifyListeners();
    } catch (_) {
      // Invalid local data is ignored so the app remains usable.
    }
  }

  List<MealEntry> mealsFor(DateTime date) {
    final entries = _meals
        .where((entry) => _isSameDay(entry.loggedAt, date))
        .toList()
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return entries;
  }

  int caloriesFor(DateTime date) =>
      mealsFor(date).fold(0, (sum, entry) => sum + entry.calories);
  double proteinFor(DateTime date) =>
      mealsFor(date).fold(0, (sum, entry) => sum + entry.protein);

  Future<void> addMeal(
      {required String name,
      required String mealType,
      required int calories,
      required double protein}) async {
    _meals.add(MealEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        mealType: mealType,
        calories: calories,
        protein: protein,
        loggedAt: DateTime.now()));
    await _commit();
  }

  Future<void> removeMeal(String id) async {
    _meals.removeWhere((entry) => entry.id == id);
    await _commit();
  }

  Future<void> updateMeal({required String id, required String name, required String mealType, required int calories, required double protein}) async {
    final index = _meals.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    final previous = _meals[index];
    _meals[index] = MealEntry(id: previous.id, name: name.trim(), mealType: mealType, calories: calories, protein: protein, loggedAt: previous.loggedAt);
    await _commit();
  }

  Future<void> addWeight(double kilograms) async {
    _weights.add(WeightEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        kilograms: kilograms,
        loggedAt: DateTime.now()));
    _weights.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    await _commit();
  }

  Future<void> updateTargets(
      {required int calories,
      required double protein,
      required double weight}) async {
    calorieTarget = calories;
    proteinTarget = protein;
    weightTarget = weight;
    await _commit();
  }

  Future<void> updateBodyProfile(
      {required double height,
      required int profileAge,
      required String sex}) async {
    heightCm = height;
    age = profileAge;
    biologicalSex = sex;
    await _commit();
  }

  Future<void> applyAiPlan(
      {required double goalWeight,
      required double weeklyLoss,
      required int calories,
      required double protein,
      required int activeCalories}) async {
    weightTarget = goalWeight;
    weeklyLossKg = weeklyLoss;
    calorieTarget = calories;
    proteinTarget = protein;
    activeCalorieTarget = activeCalories;
    await _commit();
  }

  double get exerciseCaloriesPerMinute => switch (exerciseType) {
        '散步' => 3.0,
        '快走' => 4.5,
        '慢跑' => 8.5,
        '跑步' => 10.5,
        '單車' => 7.0,
        '重訓' => 6.0,
        '游泳' => 9.0,
        '瑜伽／伸展' => 3.0,
        '有氧舞蹈' => 7.0,
        '球類運動' => 8.0,
        '間歇訓練' => 11.0,
        _ => 5.0,
      };
  Future<void> updateManualActivity(
      {required int steps, required int minutes, required String type}) async {
    activityDate = _dateKey(DateTime.now());
    manualSteps = steps;
    exerciseMinutes = minutes;
    exerciseType = type;
    await _commit();
  }

  Future<void> updateHealthActivity(
      {required int steps, required int activeCalories}) async {
    activityDate = _dateKey(DateTime.now());
    syncedSteps = steps;
    syncedActiveCalories = activeCalories;
    await _commit();
  }

  Future<void> _commit() async {
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey,
        jsonEncode({
          'meals': _meals.map((entry) => entry.toJson()).toList(),
          'weights': _weights.map((entry) => entry.toJson()).toList(),
          'calorieTarget': calorieTarget,
          'proteinTarget': proteinTarget,
          'weightTarget': weightTarget,
          'activeCalorieTarget': activeCalorieTarget,
          'weeklyLossKg': weeklyLossKg,
          'heightCm': heightCm,
          'age': age,
          'biologicalSex': biologicalSex,
          'manualSteps': manualSteps,
          'exerciseMinutes': exerciseMinutes,
          'exerciseType': exerciseType,
          'syncedSteps': syncedSteps,
          'syncedActiveCalories': syncedActiveCalories,
          'activityDate': activityDate,
        }));
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}

class DietScope extends StatefulWidget {
  const DietScope({super.key, required this.controller, required this.child});

  final DietController controller;
  final Widget child;

  static DietController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_DietScopeInherited>();
    assert(scope != null, 'DietScope is missing from the widget tree.');
    return scope!.controller;
  }

  @override
  State<DietScope> createState() => _DietScopeState();
}

class _DietScopeState extends State<DietScope> {
  late DietController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant DietScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChange);
      _controller = widget.controller;
      _controller.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DietScopeInherited(controller: _controller, child: widget.child);
  }
}

class _DietScopeInherited extends InheritedWidget {
  const _DietScopeInherited(
      {super.key, required this.controller, required super.child});

  final DietController controller;

  @override
  bool updateShouldNotify(covariant _DietScopeInherited oldWidget) =>
      controller != oldWidget.controller;
}
