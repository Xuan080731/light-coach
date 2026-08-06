import 'package:flutter/material.dart';

import 'app/diet_coach_app.dart';
import 'state/diet_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = DietController();
  await controller.load();
  runApp(DietCoachApp(controller: controller));
}
