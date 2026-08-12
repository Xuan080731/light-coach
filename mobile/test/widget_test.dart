import 'package:ai_diet_coach/app/diet_coach_app.dart';
import 'package:ai_diet_coach/state/diet_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists the selected calorie tracking mode', () async {
    final controller = DietController();
    await controller.setTrackingMode(TrackingMode.healthConnect);

    final restored = DietController();
    await restored.load();

    expect(restored.trackingMode, TrackingMode.healthConnect);
  });

  test('restores a local backup of diet data and theme preferences', () async {
    final controller = DietController();
    await controller.addMeal(
        name: '測試早餐', mealType: '早餐', calories: 420, protein: 25);
    await controller.updateTheme(
        color: AppThemeColor.ocean, brightness: AppBrightnessMode.dark);
    await controller.createLocalBackup();
    await controller.updateTheme(
        color: AppThemeColor.forest, brightness: AppBrightnessMode.light);

    final restored = await controller.restoreLocalBackup();

    expect(restored, isTrue);
    expect(controller.meals.single.name, '測試早餐');
    expect(controller.themeColor, AppThemeColor.ocean);
    expect(controller.brightnessMode, AppBrightnessMode.dark);
  });

  testWidgets('asks a new user to choose a tracking mode', (tester) async {
    await tester.pumpWidget(DietCoachApp());
    await tester.pump();
    expect(find.text('選擇使用方式'), findsOneWidget);
    await tester.tap(find.text('開始使用'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('keeps DietScope available for pushed routes', (tester) async {
    final controller = DietController();
    await controller.setTrackingMode(TrackingMode.mealLogOnly);
    await tester.pumpWidget(DietCoachApp(controller: controller));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (context) {
      final diet = DietScope.of(context);
      return Scaffold(body: Text(diet.calorieTarget.toString()));
    }));

    await tester.pumpAndSettle();

    expect(find.text('1800'), findsOneWidget);
  });

  testWidgets('saves a manually entered meal after closing its dialog',
      (tester) async {
    final controller = DietController();
    await controller.setTrackingMode(TrackingMode.mealLogOnly);
    await tester.pumpWidget(DietCoachApp(controller: controller));

    await tester.tap(find.text('飲食'));
    await tester.pump();
    await tester.tap(find.text('手動新增'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), '雞胸便當');
    await tester.enterText(find.byType(TextField).at(1), '500');
    await tester.enterText(find.byType(TextField).at(2), '42');
    await tester.tap(find.text('儲存餐點'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.meals, hasLength(1));
    expect(find.text('雞胸便當'), findsOneWidget);
  });
}
