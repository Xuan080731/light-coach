import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/meal_reminder_service.dart';
import '../../state/diet_controller.dart';
import '../activity/activity_page.dart';
import '../ai/ai_settings_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _stepCount = 6;
  static const _palette = {
    AppThemeColor.materialYou: Color(0xFF216A54),
    AppThemeColor.forest: Color(0xFF216A54),
    AppThemeColor.ocean: Color(0xFF1769AA),
    AppThemeColor.plum: Color(0xFF7B3F8C),
    AppThemeColor.amber: Color(0xFFA65E00),
  };

  final _pageController = PageController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  var _step = 0;
  var _initialized = false;
  var _saving = false;
  var _trackingMode = TrackingMode.mealLogOnly;
  var _themeColor = AppThemeColor.materialYou;
  var _brightnessMode = AppBrightnessMode.system;
  var _reminderEnabled = false;
  late MealReminderTime _reminderTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final diet = DietScope.of(context);
    _height.text = diet.heightCm.toStringAsFixed(0);
    _weight.text = diet.currentWeight?.toStringAsFixed(1) ?? '';
    _trackingMode = diet.trackingMode ?? TrackingMode.mealLogOnly;
    _themeColor = diet.themeColor;
    _brightnessMode = diet.brightnessMode;
    _reminderEnabled = diet.mealReminderEnabled;
    _reminderTime = diet.mealReminderTimes.first;
    _initialized = true;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _goToNext() async {
    if (_saving) return;
    final diet = DietScope.of(context);
    setState(() => _saving = true);
    try {
      final canContinue = switch (_step) {
        2 => await _saveBodyProfile(diet),
        3 => await _saveTrackingMode(diet),
        4 => await _saveTheme(diet),
        5 => await _saveReminder(diet),
        6 => await _finish(diet),
        _ => true,
      };
      if (canContinue && mounted && _step < _stepCount) {
        await _pageController.nextPage(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skipCurrentStep() async {
    final diet = DietScope.of(context);
    if (_step == 3) await diet.setTrackingMode(TrackingMode.mealLogOnly);
    if (!mounted) return;
    await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
  }

  Future<bool> _saveBodyProfile(DietController diet) async {
    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    if (height == null || height < 100 || height > 250) {
      _showMessage('請輸入 100 至 250 cm 的身高，或選擇稍後設定。');
      return false;
    }
    if (weight == null || weight <= 0 || weight >= 500) {
      _showMessage('請輸入合理的目前體重，或選擇稍後設定。');
      return false;
    }
    await diet.updateBodyProfile(
        height: height, profileAge: diet.age, sex: diet.biologicalSex);
    if (diet.currentWeight == null ||
        (diet.currentWeight! - weight).abs() >= 0.01) {
      await diet.addWeight(weight);
    }
    return true;
  }

  Future<bool> _saveTrackingMode(DietController diet) async {
    await diet.setTrackingMode(_trackingMode);
    return true;
  }

  Future<bool> _saveTheme(DietController diet) async {
    await diet.updateTheme(color: _themeColor, brightness: _brightnessMode);
    return true;
  }

  Future<bool> _saveReminder(DietController diet) async {
    try {
      for (final time in diet.mealReminderTimes) {
        await MealReminderService.instance
            .cancelDaily(hour: time.hour, minute: time.minute);
      }
      if (_reminderEnabled) {
        final permitted =
            await MealReminderService.instance.requestPermission();
        if (!permitted) {
          _showMessage('未取得通知權限，可稍後在設定中啟用提醒。');
          return false;
        }
        await MealReminderService.instance.scheduleDaily(
            hour: _reminderTime.hour, minute: _reminderTime.minute);
      }
      await diet.updateMealReminders(
          enabled: _reminderEnabled, times: [_reminderTime]);
      return true;
    } catch (_) {
      _showMessage('更新餐點提醒失敗，請再試一次。');
      return false;
    }
  }

  Future<bool> _finish(DietController diet) async {
    await diet.completeOnboarding();
    return false;
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: _reminderTime.hour, minute: _reminderTime.minute));
    if (picked != null && mounted) {
      setState(() {
        _reminderTime =
            MealReminderTime(hour: picked.hour, minute: picked.minute);
      });
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
            child: Row(children: [
              Text(_step == 0 ? '歡迎使用' : '開始設定',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_step > 0)
                Text('$_step / $_stepCount',
                    style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          LinearProgressIndicator(value: (_step + 1) / (_stepCount + 1)),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (value) => setState(() => _step = value),
              children: [
                _welcomeStep(context),
                _aiStep(context),
                _bodyStep(context),
                _healthStep(context),
                _themeStep(context),
                _reminderStep(context),
                _completeStep(context),
              ],
            ),
          ),
          _navigationBar(),
        ]),
      ),
    );
  }

  Widget _welcomeStep(BuildContext context) => _StepLayout(
        icon: Icons.spa_outlined,
        title: '從今天開始，輕鬆養成飲食紀錄習慣',
        description: '花一分鐘設定常用功能，之後都能隨時在設定中調整。',
        child: Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text('你的餐點、活動與健康目標會保留在這台裝置中。')),
                ]))),
      );

  Widget _aiStep(BuildContext context) => _StepLayout(
        icon: Icons.auto_awesome_outlined,
        title: '設定 AI 服務',
        description: '選擇要使用的 AI 供應商與模型，並自行輸入 API 金鑰。金鑰只會儲存在此裝置。',
        child: Card(
            child: ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('開啟 AI 服務設定'),
                subtitle: const Text('可稍後在「設定」中修改'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AiSettingsPage())))),
      );

  Widget _bodyStep(BuildContext context) => _StepLayout(
        icon: Icons.accessibility_new_outlined,
        title: '告訴我們你的身體資料',
        description: '用身高與目前體重建立較貼近你的熱量與健康趨勢。',
        child: Column(children: [
          TextField(
              controller: _height,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: const InputDecoration(
                  labelText: '身高（cm）', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(
              controller: _weight,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: const InputDecoration(
                  labelText: '目前體重（kg）',
                  helperText: '儲存後會新增第一筆體重紀錄',
                  border: OutlineInputBorder())),
        ]),
      );

  Widget _healthStep(BuildContext context) => _StepLayout(
        icon: Icons.favorite_outline,
        title: '連結活動資料',
        description: 'Health Connect 可同步步數與消耗卡路里；不會增加每日飲食額度。',
        child: Column(children: [
          Card(
              child: Column(children: [
            RadioListTile<TrackingMode>(
                value: TrackingMode.mealLogOnly,
                groupValue: _trackingMode,
                title: const Text('先用飲食紀錄開始'),
                subtitle: const Text('之後可隨時連結 Health Connect'),
                onChanged: (value) => setState(() => _trackingMode = value!)),
            const Divider(height: 1),
            RadioListTile<TrackingMode>(
                value: TrackingMode.healthConnect,
                groupValue: _trackingMode,
                title: const Text('連結 Google Health Connect'),
                subtitle: const Text('同步步數、運動與活動消耗'),
                onChanged: (value) => setState(() => _trackingMode = value!)),
          ])),
          if (_trackingMode == TrackingMode.healthConnect) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityPage())),
                icon: const Icon(Icons.sync),
                label: const Text('現在連結並同步')),
          ],
        ]),
      );

  Widget _themeStep(BuildContext context) => _StepLayout(
        icon: Icons.palette_outlined,
        title: '選擇主題與外觀',
        description: '挑選你喜歡的色彩與顯示模式；之後可以隨時更換。',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppThemeColor.values
                  .map((color) => ChoiceChip(
                      selected: _themeColor == color,
                      onSelected: (_) => setState(() => _themeColor = color),
                      avatar: CircleAvatar(backgroundColor: _palette[color]),
                      label: Text(color.label)))
                  .toList()),
          const SizedBox(height: 20),
          Text('顯示模式', style: Theme.of(context).textTheme.titleSmall),
          ...AppBrightnessMode.values.map((mode) => RadioListTile(
              contentPadding: EdgeInsets.zero,
              value: mode,
              groupValue: _brightnessMode,
              title: Text(mode.label),
              onChanged: (value) => setState(() => _brightnessMode = value!))),
        ]),
      );

  Widget _reminderStep(BuildContext context) => _StepLayout(
        icon: Icons.notifications_active_outlined,
        title: '設定餐點紀錄提醒',
        description: '每天提醒你補上餐點，讓熱量與營養進度更完整。',
        child: Card(
            child: Column(children: [
          SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('開啟每日提醒'),
              subtitle: const Text('你可以隨時在設定中新增多個時間'),
              value: _reminderEnabled,
              onChanged: (value) => setState(() => _reminderEnabled = value)),
          if (_reminderEnabled) ...[
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(_formatTime(_reminderTime)),
                subtitle: const Text('每天提醒'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickReminderTime),
          ],
        ])),
      );

  Widget _completeStep(BuildContext context) => _StepLayout(
        icon: Icons.celebration_outlined,
        title: '準備完成',
        description: '現在可以開始記錄餐點、查看每日進度，並依需要使用 AI 建議。',
        child: Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('所有設定都能在「設定」或「身體」頁面中調整。',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer)))),
      );

  Widget _navigationBar() {
    final isComplete = _step == _stepCount;
    final canSkip = _step > 0 && !isComplete;
    return SafeArea(
        top: false,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(children: [
              if (_step > 0)
                TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('上一步')),
              const Spacer(),
              if (canSkip)
                TextButton(
                    onPressed: _saving ? null : _skipCurrentStep,
                    child: const Text('稍後設定')),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: _saving ? null : _goToNext,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isComplete
                          ? '開始使用'
                          : _step == 0
                              ? '開始設定'
                              : '下一步')),
            ])));
  }

  static String _formatTime(MealReminderTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _StepLayout extends StatelessWidget {
  const _StepLayout(
      {required this.icon,
      required this.title,
      required this.description,
      required this.child});

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 30, child: Icon(icon, size: 30)),
          const SizedBox(height: 24),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          child,
        ]),
      );
}
