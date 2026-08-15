import 'package:ai_diet_coach/features/about/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> captureAboutPage(
    WidgetTester tester, {
    required Brightness brightness,
    required String goldenName,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF216A54),
          brightness: brightness,
        ),
      ),
      home: const AboutPage(enableMotion: false),
    ));
    await tester.pump();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/branding/app_icon_material_you.png'),
        tester.element(find.byType(AboutPage)),
      );
    });
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(AboutPage),
      matchesGoldenFile('goldens/$goldenName'),
    );
  }

  testWidgets('capture the light Material about page', (tester) async {
    await captureAboutPage(
      tester,
      brightness: Brightness.light,
      goldenName: 'about_page_light.png',
    );
  });

  testWidgets('capture the dark Material about page', (tester) async {
    await captureAboutPage(
      tester,
      brightness: Brightness.dark,
      goldenName: 'about_page_dark.png',
    );
  });
}
