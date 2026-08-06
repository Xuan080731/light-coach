import 'package:flutter/material.dart';

import '../features/home/home_page.dart';
import '../features/ai/ai_settings_page.dart';
import '../features/activity/activity_page.dart';
import '../features/goals/ai_goal_plan_page.dart';
import '../features/meal_log/meal_log_page.dart';
import '../features/weight/weight_page.dart';
import '../state/diet_controller.dart';

class DietCoachApp extends StatelessWidget {
  DietCoachApp({super.key, DietController? controller}) : controller = controller ?? DietController();

  final DietController controller;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF216A54));
    return MaterialApp(
      title: '輕盈教練',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xFFF8FAF7),
        appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
        cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
      home: DietScope(controller: controller, child: const _AppShell()),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onOpenMealLog: () => setState(() => _selectedIndex = 1)),
      const MealLogPage(),
      const WeightPage(),
      const _ProfilePage(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首頁'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: '飲食'),
          NavigationDestination(icon: Icon(Icons.monitor_weight_outlined), selectedIcon: Icon(Icons.monitor_weight), label: '體重'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '目標'),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('我的目標', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('這些數值用來計算每天的進度與提示。'),
      const SizedBox(height: 20),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.local_fire_department_outlined), title: const Text('每日熱量目標'), trailing: Text('${diet.calorieTarget} kcal')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.egg_alt_outlined), title: const Text('每日蛋白質目標'), trailing: Text('${diet.proteinTarget.toStringAsFixed(0)} g')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('目標體重'), trailing: Text('${diet.weightTarget.toStringAsFixed(1)} kg')),
      ])),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: () => _editTargets(context, diet), icon: const Icon(Icons.edit_outlined), label: const Text('修改目標')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsPage())), icon: const Icon(Icons.auto_awesome_outlined), label: const Text('AI 分析設定')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiGoalPlanPage())), icon: const Icon(Icons.insights_outlined), label: const Text('BMI 與 AI 減重計畫')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityPage())), icon: const Icon(Icons.directions_walk_outlined), label: const Text('步數、運動與 Health Connect')),
      const SizedBox(height: 28),
      Text('提醒', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('本工具提供飲食記錄與一般性建議，並不取代醫師或營養師的專業意見。'),
    ]);
  }

  Future<void> _editTargets(BuildContext context, DietController diet) async {
    final calories = TextEditingController(text: diet.calorieTarget.toString());
    final protein = TextEditingController(text: diet.proteinTarget.toStringAsFixed(0));
    final weight = TextEditingController(text: diet.weightTarget.toStringAsFixed(1));
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('設定目標'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _numberField(calories, '每日熱量（kcal）'),
        _numberField(protein, '每日蛋白質（g）'),
        _numberField(weight, '目標體重（kg）'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('儲存'))],
    ));
    if (saved == true) {
      final c = int.tryParse(calories.text);
      final p = double.tryParse(protein.text);
      final w = double.tryParse(weight.text);
      if (c != null && c > 0 && p != null && p > 0 && w != null && w > 0) await diet.updateTargets(calories: c, protein: p, weight: w);
    }
    calories.dispose(); protein.dispose(); weight.dispose();
  }

  Widget _numberField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );
}
