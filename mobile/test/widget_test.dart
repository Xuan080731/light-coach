import 'package:ai_diet_coach/app/diet_coach_app.dart';
import 'package:ai_diet_coach/state/diet_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an empty usable dashboard', (tester) async {
    await tester.pumpWidget(DietCoachApp());
    expect(find.text('今天的餐點'), findsOneWidget);
    expect(find.text('尚未記錄任何餐點'), findsOneWidget);
  });

  testWidgets('keeps DietScope available for pushed routes', (tester) async {
    await tester.pumpWidget(DietCoachApp());

    final navigator = Navigator.of(tester.element(find.byType(MaterialApp)));
    navigator.push(MaterialPageRoute<void>(builder: (context) {
      final diet = DietScope.of(context);
      return Scaffold(body: Text(diet.calorieTarget.toString()));
    }));

    await tester.pumpAndSettle();

    expect(find.text('1800'), findsOneWidget);
  });
}
