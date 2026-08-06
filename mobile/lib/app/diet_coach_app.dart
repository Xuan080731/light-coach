import 'package:flutter/material.dart';

import '../features/activity/activity_page.dart';
import '../features/ai/ai_settings_page.dart';
import '../features/home/home_page.dart';
import '../features/meal_log/meal_log_page.dart';
import '../features/weight/weight_page.dart';
import '../state/diet_controller.dart';

class DietCoachApp extends StatelessWidget {
  DietCoachApp({super.key, DietController? controller}) : controller = controller ?? DietController();
  final DietController controller;
  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF216A54));
    return DietScope(controller: controller, child: MaterialApp(
      title: '輕盈教練', debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: colors, scaffoldBackgroundColor: const Color(0xFFF8FAF7), appBarTheme: const AppBarTheme(scrolledUnderElevation: 0), cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))),
      home: const _AppShell(),
    ));
  }
}

class _AppShell extends StatefulWidget { const _AppShell(); @override State<_AppShell> createState() => _AppShellState(); }
class _AppShellState extends State<_AppShell> {
  var _selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [HomePage(onOpenMealLog: () => setState(() => _selectedIndex = 1)), const MealLogPage(), const WeightPage(), const _SettingsPage()];
    return Scaffold(body: SafeArea(child: pages[_selectedIndex]), bottomNavigationBar: NavigationBar(selectedIndex: _selectedIndex, onDestinationSelected: (index) => setState(() => _selectedIndex = index), destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首頁'),
      NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: '飲食'),
      NavigationDestination(icon: Icon(Icons.accessibility_new_outlined), selectedIcon: Icon(Icons.accessibility_new), label: '身體'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '設定'),
    ]));
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    Text('設定', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
    const Text('管理 AI 服務與健康資料同步。'), const SizedBox(height: 20),
    Card(child: Column(children: [
      ListTile(leading: const Icon(Icons.auto_awesome_outlined), title: const Text('AI 服務設定'), subtitle: const Text('設定供應商、模型與裝置上的 API 金鑰'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsPage()))),
      const Divider(height: 1),
      ListTile(leading: const Icon(Icons.favorite_outline), title: const Text('Google Health Connect'), subtitle: const Text('同步步數與活動消耗；也可輸入手動活動'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityPage()))),
    ])),
    const SizedBox(height: 28), Text('資料與提醒', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
    const Text('AI 建議與熱量估算僅供一般健康管理，不能取代醫療或營養專業建議。'),
  ]);
}
