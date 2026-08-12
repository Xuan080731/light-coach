import 'package:flutter/material.dart';

import 'app/diet_coach_app.dart';
import 'services/meal_reminder_service.dart';
import 'state/diet_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = DietController();
  await controller.load();
  await MealReminderService.instance.initialize();
  if (controller.mealReminderEnabled) {
    for (final time in controller.mealReminderTimes) {
      await MealReminderService.instance
          .scheduleDaily(hour: time.hour, minute: time.minute);
    }
  }
  runApp(DietCoachApp(controller: controller));
}
