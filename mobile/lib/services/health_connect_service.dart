import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthSnapshot {
  const HealthSnapshot({required this.steps, required this.activeCalories});
  final int steps;
  final int activeCalories;
}

class HealthConnectService {
  HealthConnectService({Health? health}) : _health = health ?? Health();
  final Health _health;

  Future<HealthSnapshot> syncToday() async {
    final types = [HealthDataType.STEPS, HealthDataType.ACTIVE_ENERGY_BURNED];
    final activityPermission = await Permission.activityRecognition.request();
    if (!activityPermission.isGranted) throw const HealthConnectException('需要「身體活動」權限才能讀取步數。');
    await _health.configure();
    final permissions = await _health.requestAuthorization(types);
    if (!permissions) throw const HealthConnectException('未取得 Health Connect 的步數與活動熱量權限。');
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(start, now) ?? 0;
    final data = await _health.getHealthDataFromTypes(types: [HealthDataType.ACTIVE_ENERGY_BURNED], startTime: start, endTime: now);
    final uniqueData = _health.removeDuplicates(data);
    final activeCalories = uniqueData.fold<double>(0, (total, point) {
      final value = point.value;
      return total + (value is NumericHealthValue ? value.numericValue : 0);
    }).round();
    return HealthSnapshot(steps: steps, activeCalories: activeCalories);
  }
}

class HealthConnectException implements Exception {
  const HealthConnectException(this.message);
  final String message;
}
