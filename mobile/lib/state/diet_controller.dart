import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diet_models.dart';

enum TrackingMode {
  mealLogOnly,
  healthConnect,
}

extension TrackingModeLabel on TrackingMode {
  String get label => switch (this) {
        TrackingMode.mealLogOnly => '單純飲食紀錄',
        TrackingMode.healthConnect => '連結 Health Connect',
      };
}

enum AppThemeColor {
  materialYou,
  forest,
  ocean,
  plum,
  amber,
}

extension AppThemeColorLabel on AppThemeColor {
  String get label => switch (this) {
        AppThemeColor.materialYou => 'Material You',
        AppThemeColor.forest => '森林綠',
        AppThemeColor.ocean => '海洋藍',
        AppThemeColor.plum => '紫莓色',
        AppThemeColor.amber => '琥珀色',
      };
}

enum AppBrightnessMode {
  system,
  light,
  dark,
}

class MealReminderTime {
  const MealReminderTime({required this.hour, required this.minute});

  final int hour;
  final int minute;
  int get minuteOfDay => hour * 60 + minute;

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  static MealReminderTime fromJson(Map<String, dynamic> data) =>
      MealReminderTime(
          hour: (data['hour'] as num? ?? 19).round().clamp(0, 23).toInt(),
          minute: (data['minute'] as num? ?? 30).round().clamp(0, 59).toInt());
}

extension AppBrightnessModeLabel on AppBrightnessMode {
  String get label => switch (this) {
        AppBrightnessMode.system => '跟隨系統',
        AppBrightnessMode.light => '淺色模式',
        AppBrightnessMode.dark => '深色模式',
      };
}

class DietController extends ChangeNotifier {
  static const _storageKey = 'diet_coach_data_v2';
  static const _backupKey = 'diet_coach_local_backup_v1';

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
  int exerciseMinutes = 0;
  int syncedSteps = 0;
  int syncedActiveCalories = 0;
  String activityDate = '';
  TrackingMode? trackingMode;
  AppThemeColor themeColor = AppThemeColor.materialYou;
  AppBrightnessMode brightnessMode = AppBrightnessMode.system;
  bool mealReminderEnabled = false;
  List<MealReminderTime> mealReminderTimes = [
    const MealReminderTime(hour: 19, minute: 30)
  ];

  List<MealEntry> get meals => List.unmodifiable(_meals);
  List<WeightEntry> get weights => List.unmodifiable(_weights);
  double? get currentWeight =>
      _weights.isEmpty ? null : _weights.first.kilograms;
  double? get bmi => currentWeight == null || heightCm <= 0
      ? null
      : currentWeight! / ((heightCm / 100) * (heightCm / 100));
  int get totalStepsToday => _isTodayActivity ? syncedSteps : 0;
  int get totalExerciseMinutesToday => _isTodayActivity ? exerciseMinutes : 0;
  int get estimatedActivityCalories {
    if (!_isTodayActivity) return 0;
    final manualEstimate =
        (exerciseMinutes * exerciseCaloriesPerMinute).round();
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
  bool get usesHealthConnect => trackingMode == TrackingMode.healthConnect;
  bool get hasChosenTrackingMode => trackingMode != null;
  bool get _isTodayActivity => activityDate == _dateKey(DateTime.now());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(_storageKey) ?? prefs.getString('diet_coach_data_v1');
    if (raw == null) return;
    try {
      _applyData(jsonDecode(raw) as Map<String, dynamic>);
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

  Future<void> updateMeal(
      {required String id,
      required String name,
      required String mealType,
      required int calories,
      required double protein}) async {
    final index = _meals.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    final previous = _meals[index];
    _meals[index] = MealEntry(
        id: previous.id,
        name: name.trim(),
        mealType: mealType,
        calories: calories,
        protein: protein,
        loggedAt: previous.loggedAt);
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

  double get exerciseCaloriesPerMinute => 6.0;
  Future<void> updateManualActivity({required int minutes}) async {
    activityDate = _dateKey(DateTime.now());
    exerciseMinutes = minutes;
    await _commit();
  }

  Future<void> updateHealthActivity(
      {required int steps, required int activeCalories}) async {
    activityDate = _dateKey(DateTime.now());
    syncedSteps = steps;
    syncedActiveCalories = activeCalories;
    await _commit();
  }

  Future<void> setTrackingMode(TrackingMode mode) async {
    trackingMode = mode;
    await _commit();
  }

  Future<void> updateTheme(
      {required AppThemeColor color,
      required AppBrightnessMode brightness}) async {
    themeColor = color;
    brightnessMode = brightness;
    await _commit();
  }

  Future<void> updateMealReminders({
    required bool enabled,
    required List<MealReminderTime> times,
  }) async {
    mealReminderEnabled = enabled;
    mealReminderTimes = _normalizeReminderTimes(times);
    await _commit();
  }

  Future<DateTime?> createLocalBackup() async {
    final createdAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupKey, exportBackupDocument(createdAt));
    return createdAt;
  }

  /// A portable JSON document suitable for saving outside the app.
  String exportBackupDocument([DateTime? createdAt]) => jsonEncode({
        'version': 1,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'data': _toJson(),
      });

  Future<DateTime?> localBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_backupKey);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.tryParse(value['createdAt'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<bool> restoreLocalBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_backupKey);
    if (raw == null) return false;
    return restoreBackupDocument(raw);
  }

  /// Restores a document made by [exportBackupDocument].
  Future<bool> restoreBackupDocument(String raw) async {
    try {
      final backup = jsonDecode(raw) as Map<String, dynamic>;
      final data = backup['data'];
      if (data is! Map<String, dynamic>) return false;
      _applyData(data);
      await _save();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _commit() async {
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
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
        'exerciseMinutes': exerciseMinutes,
        'syncedSteps': syncedSteps,
        'syncedActiveCalories': syncedActiveCalories,
        'activityDate': activityDate,
        'trackingMode': trackingMode?.name,
        'themeColor': themeColor.name,
        'brightnessMode': brightnessMode.name,
        'mealReminderEnabled': mealReminderEnabled,
        'mealReminderTimes':
            mealReminderTimes.map((time) => time.toJson()).toList(),
      };

  void _applyData(Map<String, dynamic> data) {
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
    activeCalorieTarget = (data['activeCalorieTarget'] as num? ?? 300).round();
    weeklyLossKg = (data['weeklyLossKg'] as num? ?? 0.3).toDouble();
    heightCm = (data['heightCm'] as num? ?? 165).toDouble();
    age = (data['age'] as num? ?? 30).round();
    biologicalSex = data['biologicalSex'] as String? ?? 'female';
    exerciseMinutes = (data['exerciseMinutes'] as num? ?? 0).round();
    syncedSteps = (data['syncedSteps'] as num? ?? 0).round();
    syncedActiveCalories = (data['syncedActiveCalories'] as num? ?? 0).round();
    activityDate = data['activityDate'] as String? ?? '';
    trackingMode = switch (data['trackingMode'] as String?) {
      'mealLogOnly' => TrackingMode.mealLogOnly,
      'healthConnect' => TrackingMode.healthConnect,
      _ => null,
    };
    themeColor = switch (data['themeColor'] as String?) {
      'forest' => AppThemeColor.forest,
      'ocean' => AppThemeColor.ocean,
      'plum' => AppThemeColor.plum,
      'amber' => AppThemeColor.amber,
      _ => AppThemeColor.materialYou,
    };
    brightnessMode = switch (data['brightnessMode'] as String?) {
      'light' => AppBrightnessMode.light,
      'dark' => AppBrightnessMode.dark,
      _ => AppBrightnessMode.system,
    };
    mealReminderEnabled = data['mealReminderEnabled'] as bool? ?? false;
    final savedTimes = data['mealReminderTimes'];
    if (savedTimes is List<dynamic>) {
      mealReminderTimes = _normalizeReminderTimes(savedTimes
          .whereType<Map>()
          .map((item) =>
              MealReminderTime.fromJson(Map<String, dynamic>.from(item)))
          .toList());
    } else {
      // Migrate the original single-time setting without losing it.
      mealReminderTimes = [
        MealReminderTime(
            hour: (data['mealReminderHour'] as num? ?? 19)
                .round()
                .clamp(0, 23)
                .toInt(),
            minute: (data['mealReminderMinute'] as num? ?? 30)
                .round()
                .clamp(0, 59)
                .toInt())
      ];
    }
  }

  static List<MealReminderTime> _normalizeReminderTimes(
      List<MealReminderTime> times) {
    final byMinute = <int, MealReminderTime>{
      for (final time in times) time.minuteOfDay: time
    };
    final normalized = byMinute.values.toList()
      ..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
    return normalized.isEmpty
        ? [const MealReminderTime(hour: 19, minute: 30)]
        : normalized;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}

/// Makes the application state available to the widget tree.
///
/// This intentionally manages [DietController] notifications itself instead
/// of extending `InheritedNotifier`. A controller notification can occur just
/// as a dialog route is being removed; keeping the notifier element from being
/// disposed in that transition prevents Flutter's `_dependents.isEmpty`
/// assertion from being triggered.
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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      _DietScopeInherited(controller: _controller, child: widget.child);
}

class _DietScopeInherited extends InheritedWidget {
  const _DietScopeInherited({required this.controller, required super.child});

  final DietController controller;

  @override
  bool updateShouldNotify(covariant _DietScopeInherited oldWidget) => true;
}
