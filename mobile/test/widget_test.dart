import 'dart:convert';

import 'package:ai_diet_coach/app/diet_coach_app.dart';
import 'package:ai_diet_coach/features/about/about_page.dart';
import 'package:ai_diet_coach/services/ai_coach_history_store.dart';
import 'package:ai_diet_coach/services/ai_service.dart';
import 'package:ai_diet_coach/services/nutrition_score_service.dart';
import 'package:ai_diet_coach/state/diet_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AI endpoints require HTTPS and official provider hosts', () {
    expect(
        AiProvider.openAiResponses
            .endpointValidationError('https://api.openai.com/v1'),
        isNull);
    expect(
        AiProvider.openAiResponses
            .endpointValidationError('http://api.openai.com/v1'),
        isNotNull);
    expect(
        AiProvider.openAiResponses
            .endpointValidationError('https://example.com/v1'),
        isNotNull);
    expect(
        AiProvider.openAiCompatible
            .endpointValidationError('https://example.com/v1'),
        isNull);
  });

  test('rejects unsupported backup versions', () async {
    final controller = DietController();
    final restored = await controller.restoreBackupDocument(
        jsonEncode({'version': 99, 'data': <String, dynamic>{}}));

    expect(restored, isFalse);
  });

  test('persists the selected calorie tracking mode', () async {
    final controller = DietController();
    await controller.setTrackingMode(TrackingMode.healthConnect);

    final restored = DietController();
    await restored.load();

    expect(restored.trackingMode, TrackingMode.healthConnect);
  });

  test('migrates old meal records without new nutrients to zero', () async {
    SharedPreferences.setMockInitialValues({
      'diet_coach_data_v2': jsonEncode({
        'meals': [
          {
            'id': 'old-meal',
            'name': '舊紀錄餐點',
            'mealType': '午餐',
            'calories': 500,
            'protein': 30,
            'loggedAt': '2026-08-17T12:00:00.000',
          }
        ],
        'weights': [],
      }),
    });

    final controller = DietController();
    await controller.load();

    expect(controller.meals.single.carbs, 0);
    expect(controller.meals.single.fat, 0);
    expect(controller.meals.single.fiber, 0);
    expect(controller.carbsTarget, 200);
    expect(controller.fatTarget, 60);
    expect(controller.fiberTarget, 25);
    expect(controller.hasCompletedOnboarding, isTrue);
  });

  test('persists onboarding completion', () async {
    final controller = DietController();
    await controller.completeOnboarding();

    final restored = DietController();
    await restored.load();

    expect(restored.hasCompletedOnboarding, isTrue);
  });

  test('nutrition score is deterministic and tolerates small overages', () {
    const service = NutritionScoreService();
    final atTarget = service.calculate(
      calorieIntake: 1800,
      calorieTarget: 1800,
      proteinIntake: 90,
      proteinTarget: 90,
      carbsIntake: 200,
      carbsTarget: 200,
      fatIntake: 60,
      fatTarget: 60,
      fiberIntake: 25,
      fiberTarget: 25,
    );
    final smallCalorieOverage = service.calculate(
      calorieIntake: 1890,
      calorieTarget: 1800,
      proteinIntake: 90,
      proteinTarget: 90,
      carbsIntake: 200,
      carbsTarget: 200,
      fatIntake: 60,
      fatTarget: 60,
      fiberIntake: 25,
      fiberTarget: 25,
    );

    expect(atTarget.totalScore, 100);
    expect(atTarget.calorieScore, 30);
    expect(smallCalorieOverage.calorieScore, 30);
    expect(smallCalorieOverage.totalScore, 100);
  });

  test('persists nutrition values and daily nutrition targets', () async {
    final controller = DietController();
    await controller.addMeal(
        name: '營養測試餐',
        mealType: '午餐',
        calories: 520,
        protein: 35,
        carbs: 55,
        fat: 18,
        fiber: 8,
        portionGrams: 420);
    await controller.updateNutritionTargets(
        calories: 1750, protein: 100, carbs: 190, fat: 58, fiber: 28);

    final restored = DietController();
    await restored.load();

    expect(restored.meals.single.carbs, 55);
    expect(restored.meals.single.fat, 18);
    expect(restored.meals.single.fiber, 8);
    expect(restored.meals.single.portionGrams, 420);
    expect(restored.carbsTarget, 190);
    expect(restored.fatTarget, 58);
    expect(restored.fiberTarget, 28);
  });

  test('stores and clears AI light coach conversation history', () async {
    final store = AiCoachHistoryStore();
    await store.save(const [
      AiCoachHistoryMessage(text: '今天蛋白質夠嗎？', isUser: true),
      AiCoachHistoryMessage(text: '還可以補一份優格。', isUser: false),
      AiCoachHistoryMessage(text: '這張餐點照片呢？', isUser: true, hasImage: true),
    ]);

    final history = await store.load();

    expect(history, hasLength(3));
    expect(history.last.hasImage, isTrue);
    expect(history[1].text, '還可以補一份優格。');

    await store.clear();
    expect(await store.load(), isEmpty);
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

  test('restores a portable backup document', () async {
    final source = DietController();
    await source.addWeight(68.5);
    await source.updateTheme(
        color: AppThemeColor.plum, brightness: AppBrightnessMode.light);

    final restored = DietController();
    final success = await restored.restoreBackupDocument(
        source.exportBackupDocument(DateTime(2026, 8, 12)));

    expect(success, isTrue);
    expect(restored.currentWeight, 68.5);
    expect(restored.themeColor, AppThemeColor.plum);
  });

  test('stores multiple daily meal reminder times in chronological order',
      () async {
    final controller = DietController();
    await controller.updateMealReminders(enabled: true, times: const [
      MealReminderTime(hour: 20, minute: 0),
      MealReminderTime(hour: 8, minute: 30),
      MealReminderTime(hour: 20, minute: 0),
    ]);

    final restored = DietController();
    await restored.load();

    expect(restored.mealReminderEnabled, isTrue);
    expect(restored.mealReminderTimes.map((time) => time.minuteOfDay),
        [8 * 60 + 30, 20 * 60]);
  });

  testWidgets('shows setup onboarding for a new user', (tester) async {
    await tester.pumpWidget(DietCoachApp());
    await tester.pump();
    expect(find.text('從今天開始，輕鬆養成飲食紀錄習慣'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('can finish onboarding with deferred setup', (tester) async {
    await tester.pumpWidget(DietCoachApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('開始設定'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 5; index++) {
      await tester.tap(find.text('稍後設定'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('開始使用'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('keeps DietScope available for pushed routes', (tester) async {
    final controller = DietController();
    await controller.setTrackingMode(TrackingMode.mealLogOnly);
    await controller.completeOnboarding();
    await tester.pumpWidget(DietCoachApp(controller: controller));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (context) {
      final diet = DietScope.of(context);
      return Scaffold(body: Text(diet.calorieTarget.toString()));
    }));

    await tester.pumpAndSettle();

    expect(find.text('1800'), findsOneWidget);
  });

  testWidgets('does not add activity calories to the food allowance',
      (tester) async {
    final controller = DietController();
    await controller.setTrackingMode(TrackingMode.healthConnect);
    await controller.completeOnboarding();
    await controller.addMeal(
        name: '午餐', mealType: '午餐', calories: 200, protein: 20);
    await controller.updateHealthActivity(steps: 4000, activeCalories: 500);

    await tester.pumpWidget(DietCoachApp(controller: controller));
    await tester.pump();

    expect(find.text('1600 kcal'), findsOneWidget);
    expect(find.text('2100 kcal'), findsNothing);
  });

  testWidgets('shows the nutrition card and opens its detail page',
      (tester) async {
    final controller = DietController();
    await controller.setTrackingMode(TrackingMode.mealLogOnly);
    await controller.completeOnboarding();
    await controller.addMeal(
        name: '均衡午餐',
        mealType: '午餐',
        calories: 600,
        protein: 35,
        carbs: 70,
        fat: 18,
        fiber: 9);

    await tester.pumpWidget(DietCoachApp(controller: controller));
    await tester.pump();

    expect(find.text('今日營養'), findsOneWidget);
    await tester.ensureVisible(find.text('今日營養'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('今日營養'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('今日營養分析'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('分數明細'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('分數明細'), findsOneWidget);
  });

  testWidgets('about page exposes product and open source information',
      (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: AboutPage(enableMotion: false)));
    await tester.pump();

    expect(find.text('輕盈教練'), findsOneWidget);
    expect(find.text('目前版本'), findsOneWidget);
    expect(find.text('開源授權'), findsOneWidget);
    expect(find.text('第三方開源授權'), findsOneWidget);
    expect(find.bySemanticsLabel('互動式輕盈教練標誌'), findsOneWidget);

    await tester.ensureVisible(find.text('開源授權'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('開源授權'));
    await tester.pumpAndSettle();

    expect(find.text('輕盈教練採用 Apache License 2.0'), findsOneWidget);
    expect(
        find.text(
            '本專案採寬鬆型開源授權，允許個人及商業使用、修改、散布與再授權；散布時請保留 LICENSE 與 NOTICE，並在修改檔案標示變更。'),
        findsOneWidget);
  });

  testWidgets('saves a manually entered meal after closing its dialog',
      (tester) async {
    final controller = DietController();
    await controller.setTrackingMode(TrackingMode.mealLogOnly);
    await controller.completeOnboarding();
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
