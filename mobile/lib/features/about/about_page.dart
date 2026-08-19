import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.enableMotion = true});

  final bool enableMotion;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Timer? _settleTimer;
  PackageInfo? _packageInfo;
  double _touchTiltX = 0;
  double _touchTiltY = 0;
  double _motionTiltX = 0;
  double _motionTiltY = 0;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    if (widget.enableMotion) _listenToMotion();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = packageInfo);
    } catch (_) {
      // The fallback below still shows the version in unsupported environments.
    }
  }

  void _listenToMotion() {
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _motionTiltX =
              (_motionTiltX - event.x * 0.025).clamp(-0.16, 0.16).toDouble();
          _motionTiltY =
              (_motionTiltY + event.y * 0.025).clamp(-0.16, 0.16).toDouble();
        });
        _settleTimer?.cancel();
        _settleTimer = Timer(const Duration(milliseconds: 140), () {
          if (!mounted) return;
          setState(() {
            _motionTiltX = 0;
            _motionTiltY = 0;
          });
        });
      },
      onError: (_) {
        // Some devices do not have a gyroscope. Touch interaction remains active.
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _gyroscopeSubscription?.cancel();
    super.dispose();
  }

  String get _versionLabel {
    final info = _packageInfo;
    if (info == null) return '1.0.0（1）';
    return '${info.version}（${info.buildNumber}）';
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _touchTiltX =
          (_touchTiltX - details.delta.dy / 260).clamp(-0.20, 0.20).toDouble();
      _touchTiltY =
          (_touchTiltY + details.delta.dx / 260).clamp(-0.20, 0.20).toDouble();
    });
  }

  void _resetTouchTilt() {
    if (!mounted) return;
    setState(() {
      _touchTiltX = 0;
      _touchTiltY = 0;
      _pressed = false;
    });
  }

  void _nudgeLogo() {
    HapticFeedback.lightImpact();
    setState(() {
      _touchTiltX = -0.07;
      _touchTiltY = 0.11;
    });
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 260), _resetTouchTilt);
  }

  void _showHighlights(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('輕盈教練能做什麼？',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              SizedBox(height: 18),
              _FeatureRow(
                  icon: Icons.restaurant_menu_outlined,
                  title: '更輕鬆地記錄飲食',
                  description: '手動輸入或透過 AI 圖片分析，整理每日熱量與蛋白質。'),
              _FeatureRow(
                  icon: Icons.favorite_outline,
                  title: '整合活動與身體資料',
                  description: '可選擇連結 Health Connect，讓健康趨勢更完整。'),
              _FeatureRow(
                  icon: Icons.auto_awesome_outlined,
                  title: '依你的資料提供建議',
                  description: 'AI 輕盈教練可參考身體與飲食紀錄，回答一般健康問題。'),
            ],
          ),
        ),
      ),
    );
  }

  void _showThirdPartyLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: '輕盈教練',
      applicationVersion: _versionLabel,
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/branding/app_icon_material_you.png',
            width: 72,
            height: 72,
          ),
        ),
      ),
      applicationLegalese: '本頁列出 App 所使用套件的開源授權條款。',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('關於'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _InteractiveLogoHero(
              colors: colors,
              pressed: _pressed,
              tiltX: _touchTiltX + _motionTiltX,
              tiltY: _touchTiltY + _motionTiltY,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: (_) => _resetTouchTilt(),
              onPanCancel: _resetTouchTilt,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTap: _nudgeLogo,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            sliver: SliverList.list(children: [
              _AboutCard(children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('目前版本'),
                  trailing: Text(_versionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: const Text('功能與理念'),
                  subtitle: const Text('用更少負擔，建立可持續的健康習慣'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showHighlights(context),
                ),
              ]),
              const SizedBox(height: 14),
              _AboutCard(children: [
                ListTile(
                  leading: const Icon(Icons.code_outlined),
                  title: const Text('開源授權'),
                  subtitle: const Text('採用 Apache License 2.0；查看完整條款'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const _ProjectLicensePage())),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('第三方開源授權'),
                  subtitle: const Text('查看 Flutter 與所有相依套件的授權條款'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThirdPartyLicenses(context),
                ),
              ]),
              const SizedBox(height: 24),
              Center(
                child: Column(children: [
                  Badge(
                    backgroundColor: colors.tertiaryContainer,
                    textColor: colors.onTertiaryContainer,
                    label: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: Text('OPEN SOURCE'),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InteractiveLogoHero extends StatelessWidget {
  const _InteractiveLogoHero({
    required this.colors,
    required this.pressed,
    required this.tiltX,
    required this.tiltY,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTap,
  });

  final ColorScheme colors;
  final bool pressed;
  final double tiltX;
  final double tiltY;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onPanCancel;
  final GestureTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(children: [
          SizedBox(
            height: 242,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: onPanUpdate,
                onPanEnd: onPanEnd,
                onPanCancel: onPanCancel,
                onTapDown: onTapDown,
                onTapUp: onTapUp,
                onTapCancel: onPanCancel,
                onTap: onTap,
                child: Semantics(
                  button: true,
                  label: '互動式輕盈教練標誌',
                  hint: '拖曳或輕觸標誌可看到動態效果',
                  child: SizedBox(
                    width: 228,
                    height: 228,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          color:
                              colors.primaryContainer.withValues(alpha: 0.44),
                          shape: BoxShape.circle,
                        ),
                      ),
                      TweenAnimationBuilder<Offset>(
                        tween: Tween(
                            end: Offset(tiltY.clamp(-0.24, 0.24),
                                tiltX.clamp(-0.24, 0.24))),
                        duration: const Duration(milliseconds: 110),
                        curve: Curves.easeOutCubic,
                        child: AnimatedScale(
                          scale: pressed ? 0.94 : 1,
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOutCubic,
                          child: Material(
                            elevation: pressed ? 5 : 14,
                            shadowColor: colors.shadow.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(44),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/branding/app_icon_material_you.png',
                              width: 154,
                              height: 154,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        builder: (context, tilt, child) => Transform.translate(
                          offset: Offset(tilt.dx * 34, tilt.dy * 34),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0015)
                              ..rotateX(tilt.dy)
                              ..rotateY(-tilt.dx)
                              ..rotateZ(tilt.dx * 0.06),
                            child: child,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Text('輕盈教練',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('讓健康紀錄更直覺，也更有掌握感',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center),
        ]),
      );
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(description),
              ],
            ),
          ),
        ]),
      );
}

class _ProjectLicensePage extends StatelessWidget {
  const _ProjectLicensePage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('開源授權')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.code_rounded, size: 56, color: colors.primary),
          const SizedBox(height: 14),
          Text('輕盈教練採用 Apache License 2.0',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text(
            '你可以使用、修改與散布本專案原始碼，包含商業用途。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Card(
            color: colors.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.verified_outlined,
                        color: colors.onTertiaryContainer),
                    const SizedBox(width: 10),
                    Text('Apache License 2.0',
                        style: TextStyle(
                            color: colors.onTertiaryContainer,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    '本專案採寬鬆型開源授權，允許個人及商業使用、修改、散布與再授權；散布時請保留 LICENSE 與 NOTICE，並在修改檔案標示變更。',
                    style: TextStyle(color: colors.onTertiaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                '第三方套件各自保留原作者與授權條款；可回到「關於」頁面的「第三方開源授權」查看完整清單。',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
