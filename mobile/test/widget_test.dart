import 'package:ai_diet_coach/app/diet_coach_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an empty usable dashboard', (tester) async {
    await tester.pumpWidget(DietCoachApp());
    expect(find.text('今天的餐點'), findsOneWidget);
    expect(find.text('尚未記錄任何餐點'), findsOneWidget);
  });
}
