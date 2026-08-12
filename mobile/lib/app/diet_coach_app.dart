import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../features/activity/activity_page.dart';
import '../features/ai/ai_settings_page.dart';
import '../features/home/home_page.dart';
import '../features/meal_log/meal_log_page.dart';
import '../features/weight/weight_page.dart';
import '../services/health_connect_service.dart';
import '../state/diet_controller.dart';

class DietCoachApp extends StatefulWidget {
  DietCoachApp({super.key, DietController? controller})
      : controller = controller ?? DietController();
  final DietController controller;

  @override
  State<DietCoachApp> createState() => _DietCoachAppState();
}

class _DietCoachAppState extends State<DietCoachApp> {
  late String _themeSignature;

  @override
  void initState() {
    super.initState();
    _themeSignature = _signature(widget.controller);
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant DietCoachApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      _themeSignature = _signature(widget.controller);
      widget.controller.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    final signature = _signature(widget.controller);
    if (signature != _themeSignature && mounted) {
      setState(() => _themeSignature = signature);
    }
  }

  static String _signature(DietController controller) =>
      '${controller.themeColor.name}|${controller.brightnessMode.name}';

  @override
  Widget build(BuildContext context) {
    final diet = widget.controller;
    return DietScope(
        controller: diet,
        child: MaterialApp(
          title: '輕盈教練',
          debugShowCheckedModeBanner: false,
          theme: _theme(ColorScheme.fromSeed(
              seedColor: const Color(0xFF216A54),
              brightness: Brightness.light)),
          darkTheme: _theme(ColorScheme.fromSeed(
              seedColor: const Color(0xFF216A54), brightness: Brightness.dark)),
          themeMode: switch (diet.brightnessMode) {
            AppBrightnessMode.system => ThemeMode.system,
            AppBrightnessMode.light => ThemeMode.light,
            AppBrightnessMode.dark => ThemeMode.dark,
          },
          builder: (context, child) =>
              DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
            final brightness = Theme.of(context).brightness;
            final colors = colorScheme(diet, brightness,
                dynamicColors:
                    brightness == Brightness.dark ? darkDynamic : lightDynamic);
            return Theme(data: _theme(colors), child: child!);
          }),
          home: const _AppShell(),
        ));
  }

  static ThemeData _theme(ColorScheme colors) => ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
      cardTheme: CardThemeData(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))));

  static ColorScheme colorScheme(DietController diet, Brightness brightness,
      {required ColorScheme? dynamicColors}) {
    if (diet.themeColor == AppThemeColor.materialYou && dynamicColors != null) {
      return dynamicColors;
    }
    return ColorScheme.fromSeed(
        seedColor: switch (diet.themeColor) {
          AppThemeColor.materialYou ||
          AppThemeColor.forest =>
            const Color(0xFF216A54),
          AppThemeColor.ocean => const Color(0xFF1769AA),
          AppThemeColor.plum => const Color(0xFF7B3F8C),
          AppThemeColor.amber => const Color(0xFFA65E00),
        },
        brightness: brightness);
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  var _selectedIndex = 0;
  var _autoSyncStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareTracking());
  }

  Future<void> _prepareTracking() async {
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;
    final diet = DietScope.of(context);
    if (!diet.hasChosenTrackingMode) {
      final mode =
          await _showTrackingModePicker(context, diet, firstSetup: true);
      if (!mounted || mode == null) return;
      await diet.setTrackingMode(mode);
    }
    if (!mounted || !diet.usesHealthConnect) return;
    await _syncHealth(diet, showSuccess: false);
  }

  Future<void> _syncHealth(DietController diet,
      {required bool showSuccess}) async {
    try {
      final snapshot = await HealthConnectService().syncToday();
      await diet.updateHealthActivity(
          steps: snapshot.steps, activeCalories: snapshot.activeCalories);
      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已同步 Google Health Connect。')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is HealthConnectException
                ? error.message
                : 'Google Health Connect 自動同步失敗。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onOpenMealLog: () => setState(() => _selectedIndex = 1)),
      const MealLogPage(),
      const WeightPage(),
      const _SettingsPage()
    ];
    return Scaffold(
        body: SafeArea(child: pages[_selectedIndex]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '首頁'),
              NavigationDestination(
                  icon: Icon(Icons.restaurant_menu_outlined),
                  selectedIcon: Icon(Icons.restaurant_menu),
                  label: '飲食'),
              NavigationDestination(
                  icon: Icon(Icons.accessibility_new_outlined),
                  selectedIcon: Icon(Icons.accessibility_new),
                  label: '身體'),
              NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '設定'),
            ]));
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();
  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('設定',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('管理 AI 服務與健康資料同步。'),
      const SizedBox(height: 20),
      Card(
          child: Column(children: [
        ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('AI 服務設定'),
            subtitle: const Text('設定供應商、模型與裝置上的 API 金鑰'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsPage()))),
        const Divider(height: 1),
        ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: const Text('熱量計算方式'),
            subtitle: Text(diet.trackingMode?.label ?? '尚未設定'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changeTrackingMode(context, diet)),
        const Divider(height: 1),
        ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主題與外觀'),
            subtitle:
                Text('${diet.themeColor.label} · ${diet.brightnessMode.label}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _ThemeSettingsPage()))),
        const Divider(height: 1),
        ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Google Health Connect'),
            subtitle: Text(diet.usesHealthConnect
                ? '已用於計算運動額外消耗'
                : '切換為 Health Connect 模式後可同步'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ActivityPage()))),
        const Divider(height: 1),
        ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('本機備份與還原'),
            subtitle: const Text('在這台裝置建立與還原資料備份'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const _BackupSettingsPage()))),
      ])),
      const SizedBox(height: 28),
      Text('資料與提醒',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('AI 建議與熱量估算僅供一般健康管理，不能取代醫療或營養專業建議。'),
    ]);
  }

  Future<void> _changeTrackingMode(
      BuildContext context, DietController diet) async {
    final mode = await _showTrackingModePicker(context, diet);
    if (mode == null || mode == diet.trackingMode) return;
    await diet.setTrackingMode(mode);
    if (!context.mounted) return;
    if (mode == TrackingMode.healthConnect) {
      try {
        final snapshot = await HealthConnectService().syncToday();
        await diet.updateHealthActivity(
            steps: snapshot.steps, activeCalories: snapshot.activeCalories);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已連結並同步 Google Health Connect。')));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error is HealthConnectException
                  ? error.message
                  : 'Google Health Connect 同步失敗。')));
        }
      }
    }
  }
}

Future<TrackingMode?> _showTrackingModePicker(
    BuildContext context, DietController diet,
    {bool firstSetup = false}) async {
  var selected = diet.trackingMode ?? TrackingMode.mealLogOnly;
  return showDialog<TrackingMode>(
      context: context,
      barrierDismissible: !firstSetup,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                  title: Text(firstSetup ? '選擇使用方式' : '熱量計算方式'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(firstSetup
                        ? '先選擇你想使用的紀錄方式，之後可隨時在設定變更。'
                        : '此設定會影響首頁的熱量摘要。'),
                    const SizedBox(height: 16),
                    _TrackingModeOption(
                        mode: TrackingMode.mealLogOnly,
                        selected: selected,
                        icon: Icons.restaurant_outlined,
                        title: '單純飲食紀錄',
                        description: '記錄餐點與每日攝取，不連結運動資料。',
                        onTap: () => setDialogState(
                            () => selected = TrackingMode.mealLogOnly)),
                    const SizedBox(height: 10),
                    _TrackingModeOption(
                        mode: TrackingMode.healthConnect,
                        selected: selected,
                        icon: Icons.favorite_outline,
                        title: '連結 Health Connect',
                        description: '將運動額外消耗納入今日可用熱量。',
                        onTap: () => setDialogState(
                            () => selected = TrackingMode.healthConnect)),
                  ]),
                  actions: [
                    if (!firstSetup)
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, selected),
                        child: Text(firstSetup ? '開始使用' : '儲存設定')),
                  ])));
}

class _TrackingModeOption extends StatelessWidget {
  const _TrackingModeOption(
      {required this.mode,
      required this.selected,
      required this.icon,
      required this.title,
      required this.description,
      required this.onTap});

  final TrackingMode mode;
  final TrackingMode selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == selected;
    final colors = Theme.of(context).colorScheme;
    return Material(
        color: isSelected ? colors.primaryContainer : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(icon, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(description,
                            style: Theme.of(context).textTheme.bodySmall),
                      ])),
                  Radio<TrackingMode>(
                      value: mode,
                      groupValue: selected,
                      onChanged: (_) => onTap()),
                ]))));
  }
}

class _ThemeSettingsPage extends StatelessWidget {
  const _ThemeSettingsPage();

  static const _paletteColors = {
    AppThemeColor.materialYou: Color(0xFF216A54),
    AppThemeColor.forest: Color(0xFF216A54),
    AppThemeColor.ocean: Color(0xFF1769AA),
    AppThemeColor.plum: Color(0xFF7B3F8C),
    AppThemeColor.amber: Color(0xFFA65E00),
  };

  @override
  Widget build(BuildContext context) {
    final diet = DietScope.of(context);
    return Scaffold(
        appBar: AppBar(title: const Text('主題與外觀')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('主題色彩', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Material You 會優先使用手機壁紙的系統色票。'),
          const SizedBox(height: 16),
          Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppThemeColor.values
                  .map((themeColor) => _ThemeColorChoice(
                      label: themeColor.label,
                      color: _paletteColors[themeColor]!,
                      selected: diet.themeColor == themeColor,
                      isDynamic: themeColor == AppThemeColor.materialYou,
                      onTap: () => diet.updateTheme(
                          color: themeColor, brightness: diet.brightnessMode)))
                  .toList()),
          const SizedBox(height: 30),
          Text('顯示模式', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...AppBrightnessMode.values.map((mode) => RadioListTile(
              value: mode,
              groupValue: diet.brightnessMode,
              title: Text(mode.label),
              onChanged: (value) {
                if (value == null) return;
                diet.updateTheme(color: diet.themeColor, brightness: value);
              })),
        ]));
  }
}

class _ThemeColorChoice extends StatelessWidget {
  const _ThemeColorChoice(
      {required this.label,
      required this.color,
      required this.selected,
      required this.isDynamic,
      required this.onTap});

  final String label;
  final Color color;
  final bool selected;
  final bool isDynamic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: CircleAvatar(
          backgroundColor: color,
          child: isDynamic ? const Icon(Icons.auto_awesome, size: 16) : null),
      label: Text(label));
}

class _BackupSettingsPage extends StatefulWidget {
  const _BackupSettingsPage();

  @override
  State<_BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<_BackupSettingsPage> {
  DateTime? _backupTime;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBackupTime());
  }

  Future<void> _loadBackupTime() async {
    final time = await DietScope.of(context).localBackupTime();
    if (mounted)
      setState(() {
        _backupTime = time;
        _loading = false;
      });
  }

  Future<void> _createBackup() async {
    final time = await DietScope.of(context).createLocalBackup();
    if (!mounted) return;
    setState(() => _backupTime = time);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已建立本機備份。')));
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('還原本機備份？'),
                content: const Text('目前的飲食、體重、目標與外觀設定會被備份內容覆蓋。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('還原')),
                ]));
    if (confirmed != true || !mounted) return;
    final restored = await DietScope.of(context).restoreLocalBackup();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(restored ? '已還原本機備份。' : '找不到可還原的備份。')));
    await _loadBackupTime();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('本機備份與還原')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本機備份',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(_loading
                          ? '正在讀取備份狀態…'
                          : _backupTime == null
                              ? '尚未建立備份'
                              : '最近備份：${_formatDateTime(_backupTime!)}'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                          onPressed: _loading ? null : _createBackup,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('立即建立備份')),
                    ]))),
        const SizedBox(height: 14),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('還原資料',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text('可還原這台裝置上最近建立的一份備份。'),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                          onPressed:
                              _backupTime == null ? null : _restoreBackup,
                          icon: const Icon(Icons.restore),
                          label: const Text('還原最近備份')),
                    ]))),
      ]));

  static String _formatDateTime(DateTime time) =>
      '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
