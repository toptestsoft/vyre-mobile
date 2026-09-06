import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:upgrader/upgrader.dart';
import 'package:upgrader/src/upgrade_store_controller.dart';

// ═══════════════════════════════════════════════════════════
//  VEIL VPN 2.0 — 2026 CYBER-GLASS AESTHETIC
// ═══════════════════════════════════════════════════════════

// ─── Core Palette ───
const Color kVoid = Color(0xFF030305);
const Color kSurface = Color(0xFF0A0A0F);
const Color kSurfaceLight = Color(0xFF13131A);
const Color kGlass = Color(0x18FFFFFF);
const Color kGlassBorder = Color(0x22FFFFFF);
const Color kAccentCyan = Color(0xFF00F0FF);
const Color kAccentPurple = Color(0xFF8B5CF6);
const Color kAccentMagenta = Color(0xFFE879F9);
const Color kGlowCyan = Color(0x4400F0FF);
const Color kGlowPurple = Color(0x448B5CF6);
const Color kTextPrimary = Color(0xFFF8FAFC);
const Color kTextSecondary = Color(0xFF94A3B8);
const Color kTextMuted = Color(0xFF475569);
const Color kSuccess = Color(0xFF34D399);
const Color kDanger = Color(0xFFFB7185);

// ─── Telegram Bot ───
const String kTelegramBot = 'VYREPayBot';
const String kTelegramChannel = 'VYREPrivacy';

// ─── Typography ───
const String kFont = 'Geist';

class ServerRow {
  ServerRow(this.remark, this.config, this.delayMs);
  final String remark;
  final String config;
  final int delayMs;
}

class SubscriptionItem {
  SubscriptionItem({required this.name, required this.url, this.servers = const []});
  final String name;
  final String url;
  final List<ServerRow> servers;

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'servers': servers
            .map((s) => {'remark': s.remark, 'config': s.config, 'delayMs': s.delayMs})
            .toList()
      };
  static SubscriptionItem fromJson(Map<String, dynamic> json) => SubscriptionItem(
        name: json['name'] as String,
        url: json['url'] as String,
        servers: (json['servers'] as List<dynamic>?)?.map((s) {
              final m = Map<String, dynamic>.from(s as Map);
              return ServerRow(
                m['remark'] as String? ?? '',
                m['config'] as String? ?? '',
                m['delayMs'] as int? ?? -1,
              );
            }).toList() ??
            [],
      );
}

void main() {
  runApp(const VYREApp());
}

/// Конфигурация автообновления через GitHub Releases
/// Используем UpgraderAppcastStore с кастомным appcast URL
/// Для GitHub создадим простой appcast endpoint
class VYREUpgraderConfig {
  static UpgraderStoreController createStoreController() {
    return UpgraderStoreController(
      onAndroid: () => UpgraderAppcastStore(
        appcastURL: 'https://raw.githubusercontent.com/toptestsoft/vyre-mobile/main/appcast.xml',
      ),
    );
  }
}

class VYREApp extends StatelessWidget {
  const VYREApp({super.key});

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      upgrader: Upgrader(
        durationUntilAlertAgain: const Duration(hours: 1),
        debugLogging: false,
        debugDisplayAlways: false,
        debugDisplayOnce: false,
        showOnlyMandatoryUpdates: false,
        storeController: VYREUpgraderConfig.createStoreController(),
      ),
      child: MaterialApp(
      title: 'VYRE VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kVoid,
        colorScheme: const ColorScheme.dark(
          primary: kAccentCyan,
          secondary: kAccentPurple,
          surface: kSurface,
          background: kVoid,
          onBackground: kTextPrimary,
          onSurface: kTextPrimary,
        ),
        fontFamily: kFont,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.3),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextPrimary),
          bodyLarge: TextStyle(fontSize: 16, color: kTextSecondary, height: 1.5),
          bodyMedium: TextStyle(fontSize: 14, color: kTextSecondary, height: 1.4),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        iconTheme: const IconThemeData(color: kTextSecondary, size: 22),
        dividerTheme: const DividerThemeData(color: kGlassBorder, space: 1),
      ),
      home: const VYREHome(),
    );
  }
}

// ─── Glass Card ───
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final Color? tint;
  final Border? border;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.tint,
    this.border,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius!),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tint ?? kGlass,
            borderRadius: BorderRadius.circular(radius!),
            border: border ?? Border.all(color: kGlassBorder, width: 1),
            boxShadow: shadows ?? [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Gradient Text ───
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;

  const GradientText(this.text, {super.key, required this.style, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  HOME SCREEN
// ═══════════════════════════════════════════════════════════

class VYREHome extends StatefulWidget {
  const VYREHome({super.key});

  @override
  State<VYREHome> createState() => _VYREHomeState();
}

class _VYREHomeState extends State<VYREHome> with TickerProviderStateMixin {
  late final FlutterV2ray _v2ray;
  final TextEditingController _subController = TextEditingController(text: 'https://');

  bool _connected = false;
  String _statusText = 'Отключено';
  List<ServerRow> _servers = [];
  String _error = '';
  bool _testing = false;
  bool _isInitialized = false;

  List<AppInfo> _allApps = [];
  Set<String> _selectedPackages = {};
  bool _appsLoaded = false;

  List<SubscriptionItem> _subscriptions = [];
  int _activeSubIndex = -1;

  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        setState(() {
          _connected = status.state == 'CONNECTED';
          _statusText = _connLabel(status.state);
        });
      },
    );

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );

    _glowController.repeat(reverse: true);

    _initEngine();
    _loadAppsIfNeeded();
    _loadSavedSelection();
    _loadSubscriptions();
    _loadActiveSubIndex();
  }

  @override
  void dispose() {
    if (_isInitialized) _v2ray.stopV2Ray();
    _pulseController.dispose();
    _glowController.dispose();
    _subController.dispose();
    super.dispose();
  }

  Future<void> _initEngine() async {
    try {
      await _v2ray.initializeV2Ray();
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка инициализации: $e');
    }
  }

  Future<void> _loadAppsIfNeeded() async {
    if (_appsLoaded) return;
    try {
      final apps = await InstalledApps.getInstalledApps(
        withIcon: false,
        excludeNonLaunchableApps: true,
        excludeSystemApps: false,
      );
      if (!mounted) return;
      setState(() {
        _allApps = apps;
        _appsLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить приложения: $e');
    }
  }

  void _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_packages', _selectedPackages.toList());
  }

  void _loadSavedSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('selected_packages');
    if (saved != null && mounted) {
      setState(() => _selectedPackages = saved.toSet());
    }
  }

  void _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _subscriptions.map((s) => json.encode(s.toJson())).toList();
    await prefs.setStringList('subscriptions', jsonList);
  }

  void _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('subscriptions') ?? [];
    final subs = jsonList.map((j) => SubscriptionItem.fromJson(json.decode(j))).toList();
    if (!mounted) return;
    setState(() => _subscriptions = subs);
  }

  void _saveActiveSubIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_sub_index', _activeSubIndex);
  }

  void _loadActiveSubIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('active_sub_index');
    if (!mounted) return;
    if (idx != null && idx >= 0 && idx < _subscriptions.length) {
      setState(() {
        _activeSubIndex = idx;
        _subController.text = _subscriptions[idx].url;
      });
    }
  }

  String _connLabel(String s) {
    switch (s) {
      case 'CONNECTED':
        return 'Подключено';
      case 'CONNECTING':
        return 'Подключение…';
      case 'DISCONNECTING':
        return 'Отключение…';
      case 'CONNECTED_NOT':
      case 'DISCONNECTED_NOT':
        return 'Статус неизвестен';
      case 'DISCONNECTED':
      default:
        return 'Отключено';
    }
  }

  // ─── Telegram Bot Link ───
  Future<void> _openTelegram() async {
    final uri = Uri.parse('https://t.me/$kTelegramBot');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        setState(() => _error = 'Не удалось открыть Telegram');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка открытия Telegram: $e');
    }
  }

  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0a0a1a), // тёмный непрозрачный фон
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('О VYRE', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Версия: 1.0.0', style: TextStyle(color: kTextSecondary)),
            SizedBox(height: 8),
            Text('Группа в Telegram: @VYREPrivacy',
                style: TextStyle(color: kTextSecondary)),
            SizedBox(height: 8),
            Text('Лицензия: MIT', style: TextStyle(color: kTextSecondary)),
            SizedBox(height: 4),
            Text('Исходный код: github.com/toptestsoft',
                style: TextStyle(color: kTextMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ОК', style: TextStyle(color: kAccentCyan)),
          ),
        ],
      ),
    );
  }

  List<V2RayURL> _parseInput(String body, {required bool isSingleLink}) {
    if (isSingleLink) {
      try {
        return [FlutterV2ray.parseFromURL(body)];
      } catch (_) {
        return [];
      }
    }
    String text = body.trim();
    if (!text.contains('://') && !text.contains('{')) {
      try {
        final normalized = text.replaceAll(RegExp(r'\s+'), '');
        text = utf8.decode(base64Decode(normalized));
      } catch (_) {}
    }
    final urls = <V2RayURL>[];
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final u = FlutterV2ray.parseFromURL(t);
        urls.add(u);
      } catch (_) {}
    }
    return urls;
  }

  Future<void> _connect() async {
    if (!mounted) return;
    setState(() {
      _error = '';
      _testing = false;
      _servers = [];
    });

    if (!_isInitialized) {
      setState(() => _error = 'Движок не инициализирован');
      return;
    }

    final subUrl = _subController.text.trim();
    if (subUrl.isEmpty || subUrl == 'https://') {
      setState(() => _error = 'Введите ссылку подписки');
      return;
    }

    if (!_subscriptions.any((s) => s.url == subUrl)) {
      setState(() {
        _subscriptions.add(SubscriptionItem(
          name: 'Подписка ${_subscriptions.length + 1}',
          url: subUrl,
        ));
        _activeSubIndex = _subscriptions.length - 1;
      });
      _saveSubscriptions();
      _saveActiveSubIndex();
    }

    try {
      setState(() => _testing = true);
      _pulseController.repeat(reverse: true);

      final lower = subUrl.toLowerCase();
      String body;
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        final response = await http
            .get(Uri.parse(subUrl), headers: {'User-Agent': 'VYRE/2.0'})
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw Exception('Ошибка загрузки подписки: ${response.statusCode}');
        }
        body = response.body;
      } else {
        body = subUrl;
      }

      final bool isSingleLink = lower.startsWith('vless://') ||
          lower.startsWith('vmess://') ||
          lower.startsWith('trojan://') ||
          lower.startsWith('ss://') ||
          lower.startsWith('socks://') ||
          lower.startsWith('hy2://') ||
          lower.startsWith('hysteria2://');

      final List<V2RayURL> parsed = _parseInput(body, isSingleLink: isSingleLink);
      if (parsed.isEmpty) {
        setState(() {
          _error = 'Подписка не содержит серверов';
          _testing = false;
        });
        _pulseController.stop();
        return;
      }

      final futures = parsed.map((p) async {
        final cfg = p.getFullConfiguration();
        int ms = -1;
        try {
          ms = await _v2ray.getServerDelay(config: cfg);
        } catch (_) {}
        return ServerRow(p.remark, cfg, ms);
      }).toList();
      final rows = await Future.wait(futures);
      rows.sort((a, b) => a.delayMs.compareTo(b.delayMs));

      if (!mounted) return;
      setState(() {
        _servers = rows;
        _testing = false;
      });
      _pulseController.stop();

      final best = rows.firstWhere(
        (r) => r.config.isNotEmpty,
        orElse: () => rows.first,
      );

      List<String>? blockedAppsList;
      if (_selectedPackages.isNotEmpty) {
        final allPackageNames = _allApps.map((app) => app.packageName).toList();
        blockedAppsList = allPackageNames
            .where((pkg) => !_selectedPackages.contains(pkg))
            .toList();
      }

      final granted = await _v2ray.requestPermission();
      if (!granted) {
        setState(() => _error = 'Нет прав на VPN (отклонено)');
        return;
      }

      await _v2ray.startV2Ray(
        remark: best.remark.isEmpty ? 'VYRE' : best.remark,
        config: best.config,
        blockedApps: blockedAppsList,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка: $e';
        _testing = false;
      });
      _pulseController.stop();
    }
  }

  Future<void> _disconnect() async {
    try {
      await _v2ray.stopV2Ray();
      _pulseController.stop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка отключения: $e');
    }
  }

  Future<void> _openQrScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _subController.text = result;
        _error = '';
      });
    }
  }

  void _openAppSelection() async {
    if (!_appsLoaded) await _loadAppsIfNeeded();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppSelectionScreen(
          apps: _allApps,
          selectedPackages: _selectedPackages,
          onSave: (selected) {
            setState(() {
              _selectedPackages = selected;
              _saveSelection();
            });
          },
        ),
      ),
    );
  }

  void _showManageSubscriptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubscriptionsSheet(
        subscriptions: _subscriptions,
        activeIndex: _activeSubIndex,
        onSelect: (i) {
          setState(() {
            _activeSubIndex = i;
            _subController.text = _subscriptions[i].url;
          });
          _saveActiveSubIndex();
        },
        onAdd: (url) {
          setState(() {
            _subscriptions.add(SubscriptionItem(
              name: 'Подписка ${_subscriptions.length + 1}',
              url: url,
            ));
            _activeSubIndex = _subscriptions.length - 1;
            _subController.text = url;
          });
          _saveSubscriptions();
          _saveActiveSubIndex();
        },
        onDelete: (i) {
          setState(() {
            _subscriptions.removeAt(i);
            if (_activeSubIndex >= _subscriptions.length) {
              _activeSubIndex = _subscriptions.isEmpty ? -1 : _subscriptions.length - 1;
            }
            if (_subscriptions.isNotEmpty) {
              _subController.text = _subscriptions[_activeSubIndex.clamp(0, _subscriptions.length - 1)].url;
            } else {
              _subController.text = '';
            }
          });
          _saveSubscriptions();
          _saveActiveSubIndex();
        },
      ),
    );
  }

  void _showServersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ServersSheet(servers: _servers),
    );
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final statusColor = _connected ? kSuccess : kDanger;
    final statusGlow = _connected ? kGlowCyan : kGlowPurple;

    return Scaffold(
      backgroundColor: kVoid,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            // Логотип VYRE — как на официальном логотипе
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0a0a1a),  // почти чёрный с синевой
                    Color(0xFF1a1a3a),  // тёмно-синий
                    Color(0xFF2d1f6e),  // тёмно-фиолетовый
                    Color(0xFF7c4dff),  // фиолетовый
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF7c4dff).withOpacity(0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7c4dff).withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Center(
                child: Text('V', style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                )),
              ),
            ),
            const SizedBox(width: 8),
            // Текст "VYRE" — белый, как на логотипе
            const Text('VYRE', style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 1,
              color: Colors.white,
            )),
          ],
        ),
        actions: [
          _GlassIconButton(icon: Icons.qr_code_scanner, onTap: _openQrScanner),
          _GlassIconButton(icon: Icons.apps, onTap: _openAppSelection),
          _GlassIconButton(
            icon: Icons.telegram,
            onTap: _openTelegram,
            tooltip: 'Подписка в Telegram',
          ),
          _GlassIconButton(
            icon: Icons.info_outline,
            onTap: _showAboutApp,
            tooltip: 'О приложении',
          ),
          _GlassIconButton(
            icon: Icons.more_vert,
            onTap: () => _showManageSubscriptions(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Ambient background glow
          Positioned(
            top: -100,
            left: -100,
            child: _AmbientOrb(
              size: 300,
              color: _connected ? kAccentCyan.withOpacity(0.12) : kAccentPurple.withOpacity(0.10),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: _AmbientOrb(
              size: 250,
              color: _connected ? kAccentPurple.withOpacity(0.08) : kAccentMagenta.withOpacity(0.06),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // ── Bento Status ──
                    _BentoStatus(
                      connected: _connected,
                      statusText: _statusText,
                      selectedCount: _selectedPackages.length,
                      serverCount: _servers.length,
                      activeSub: _activeSubIndex >= 0 ? _subscriptions[_activeSubIndex].name : null,
                    ),

                    const SizedBox(height: 28),

                    // ── Connection Orb ──
                    Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_pulseAnim, _glowAnim]),
                        builder: (context, child) {
                          final isPulsing = _testing || _connected;
                          return GestureDetector(
                            onTap: _connected ? _disconnect : _connect,
                            child: SizedBox(
                              width: 220,
                              height: 220,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 220 * (isPulsing ? _pulseAnim.value : 1.0),
                                    height: 220 * (isPulsing ? _pulseAnim.value : 1.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          statusGlow.withOpacity(_glowAnim.value),
                                          statusGlow.withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: _connected
                                            ? [kAccentCyan.withOpacity(0.3), kAccentPurple.withOpacity(0.2)]
                                            : [kSurfaceLight, kSurface],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: _connected ? kAccentCyan.withOpacity(0.4) : kGlassBorder,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusColor.withOpacity(0.25),
                                          blurRadius: 40,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _connected ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                            size: 56,
                                            color: _connected ? kDanger : kTextPrimary,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _connected ? 'СТОП' : 'СТАРТ',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 2,
                                              color: kTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Active server label ──
                    if (_servers.isNotEmpty)
                      Center(
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          radius: 24,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _servers.first.remark.isEmpty ? 'Быстрый сервер' : _servers.first.remark,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              if (_servers.first.delayMs >= 0) ...[
                                const SizedBox(width: 6),
                                Text('${_servers.first.delayMs} мс', style: const TextStyle(fontSize: 12, color: kTextMuted)),
                              ],
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ── Subscription Input ──
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.link, size: 18, color: kAccentCyan),
                              const SizedBox(width: 8),
                              const Text('Ссылка подписки', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
                              const Spacer(),
                              if (_subController.text.length > 8)
                                GestureDetector(
                                  onTap: () {
                                    _subController.clear();
                                    setState(() {});
                                  },
                                  child: const Icon(Icons.close, size: 18, color: kTextMuted),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: TextField(
                                controller: _subController,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: kTextPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.03),
                                  hintText: 'https://... или vless://',
                                  hintStyle: const TextStyle(color: kTextMuted),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  suffixIcon: _subController.text.length > 8
                                      ? IconButton(
                                          icon: const Icon(Icons.content_paste, size: 18, color: kTextSecondary),
                                          onPressed: () {},
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          if (_testing) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(
                              backgroundColor: kSurfaceLight,
                              valueColor: AlwaysStoppedAnimation<Color>(kAccentCyan),
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                          ],
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(_error, style: const TextStyle(color: kDanger, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Servers Preview ──
                    if (_servers.isNotEmpty)
                      GestureDetector(
                        onTap: _showServersSheet,
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.dns, color: kAccentPurple, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Доступные серверы', style: TextStyle(fontWeight: FontWeight.w600)),
                                    Text('${_servers.length} найдено · Лучший: ${_servers.first.delayMs >= 0 ? '${_servers.first.delayMs} мс' : 'N/A'}',
                                        style: const TextStyle(fontSize: 12, color: kTextMuted)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_up, color: kTextMuted),
                            ],
                          ),
                        ),
                      )
                    else
                      GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        tint: Colors.white.withOpacity(0.02),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off, color: kTextMuted.withOpacity(0.5), size: 24),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Нет серверов. Введите ссылку и нажмите СТАРТ',
                                style: TextStyle(color: kTextMuted, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glass Icon Button ───
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _GlassIconButton({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kGlass,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kGlassBorder),
          ),
          child: Icon(icon, color: kTextSecondary, size: 17),
        ),
      ),
    );
  }
}

// ─── Ambient Orb Background ───
class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _AmbientOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

// ─── Bento Status Grid ───
class _BentoStatus extends StatelessWidget {
  final bool connected;
  final String statusText;
  final int selectedCount;
  final int serverCount;
  final String? activeSub;

  const _BentoStatus({
    required this.connected,
    required this.statusText,
    required this.selectedCount,
    required this.serverCount,
    this.activeSub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: GlassCard(
                padding: const EdgeInsets.all(18),
                tint: connected ? kGlowCyan : kGlowPurple,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: connected ? kSuccess : kDanger,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (connected ? kSuccess : kDanger).withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          statusText.toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: kTextSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GradientText(
                      connected ? 'Защищено' : 'Отключено',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                      colors: connected
                          ? [kAccentCyan, kSuccess]
                          : [kTextPrimary, kTextSecondary],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected ? 'Трафик шифруется через VYRE' : 'Введите ссылку подписки или VLESS-ссылку',
                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.speed, color: kAccentPurple, size: 20),
                        const SizedBox(height: 8),
                        Text(
                          serverCount > 0 ? '$serverCount' : '—',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const Text('Серверов', style: TextStyle(fontSize: 11, color: kTextMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.apps, color: kAccentMagenta, size: 20),
                        const SizedBox(height: 8),
                        Text(
                          selectedCount > 0 ? '$selectedCount' : 'Все',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const Text('Приложений', style: TextStyle(fontSize: 11, color: kTextMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (activeSub != null) ...[
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            radius: 16,
            child: Row(
              children: [
                const Icon(Icons.subscriptions, size: 16, color: kAccentCyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    activeSub!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.check_circle, size: 16, color: kSuccess),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SERVERS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════
class _ServersSheet extends StatelessWidget {
  final List<ServerRow> servers;
  const _ServersSheet({required this.servers});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (ctx, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: kSurface.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: const Border(top: BorderSide(color: kGlassBorder)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kTextMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text('Серверы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        Spacer(),
                        Text('по задержке', style: TextStyle(fontSize: 12, color: kTextMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: servers.length,
                      itemBuilder: (ctx, i) {
                        final s = servers[i];
                        final isBest = i == 0 && s.delayMs >= 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isBest ? kAccentCyan.withOpacity(0.08) : kGlass,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isBest ? kAccentCyan.withOpacity(0.3) : kGlassBorder,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isBest ? kAccentCyan.withOpacity(0.15) : kSurfaceLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.dns,
                                color: isBest ? kAccentCyan : kTextSecondary,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              s.remark.isEmpty ? 'Сервер ${i + 1}' : s.remark,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              s.delayMs < 0 ? 'Нет ответа' : '${s.delayMs} мс',
                              style: TextStyle(
                                fontSize: 12,
                                color: s.delayMs < 0 ? kTextMuted : (isBest ? kSuccess : kTextSecondary),
                              ),
                            ),
                            trailing: isBest
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kSuccess.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'ЛУЧШИЙ',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kSuccess),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SUBSCRIPTIONS SHEET
// ═══════════════════════════════════════════════════════════
class _SubscriptionsSheet extends StatefulWidget {
  final List<SubscriptionItem> subscriptions;
  final int activeIndex;
  final Function(int) onSelect;
  final Function(String) onAdd;
  final Function(int) onDelete;

  const _SubscriptionsSheet({
    required this.subscriptions,
    required this.activeIndex,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<_SubscriptionsSheet> createState() => _SubscriptionsSheetState();
}

class _SubscriptionsSheetState extends State<_SubscriptionsSheet> {
  final TextEditingController _urlCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: kSurface.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: const Border(top: BorderSide(color: kGlassBorder)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: kTextMuted, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Подписки', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: widget.subscriptions.length,
                      itemBuilder: (ctx, i) {
                        final s = widget.subscriptions[i];
                        final isActive = i == widget.activeIndex;
                        return GestureDetector(
                          onTap: () {
                            widget.onSelect(i);
                            Navigator.pop(context);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isActive ? kAccentPurple.withOpacity(0.12) : kGlass,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isActive ? kAccentPurple.withOpacity(0.4) : kGlassBorder,
                                width: isActive ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: isActive
                                        ? const LinearGradient(colors: [kAccentPurple, kAccentMagenta])
                                        : null,
                                    color: isActive ? null : kSurfaceLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.link,
                                    color: isActive ? Colors.white : kTextSecondary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(s.url, style: const TextStyle(fontSize: 12, color: kTextMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  const Icon(Icons.check_circle, color: kSuccess, size: 22),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    showDialog(context: ctx, builder: (ctx2) => AlertDialog(
                                      backgroundColor: kGlass,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Text('Удалить подписку?', style: TextStyle(color: Colors.white)),
                                      content: Text('${s.name}\n${s.url}', style: const TextStyle(color: kTextSecondary)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Отмена', style: TextStyle(color: kTextMuted))),
                                        TextButton(onPressed: () { Navigator.pop(ctx2); widget.onDelete(i); Navigator.pop(context); }, child: const Text('Удалить', style: TextStyle(color: kDanger))),
                                      ],
                                    ));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: kDanger.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.delete_outline, color: kDanger, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_adding) ...[
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: TextField(
                              controller: _urlCtrl,
                              style: const TextStyle(color: kTextPrimary),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: kSurfaceLight,
                                hintText: 'https://...',
                                hintStyle: const TextStyle(color: kTextMuted),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccentPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                final url = _urlCtrl.text.trim();
                                if (url.isNotEmpty) {
                                  widget.onAdd(url);
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('Добавить подписку', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTextPrimary,
                            side: const BorderSide(color: kGlassBorder),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => setState(() => _adding = true),
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить подписку', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  APP SELECTION SCREEN
// ═══════════════════════════════════════════════════════════
class AppSelectionScreen extends StatefulWidget {
  final List<AppInfo> apps;
  final Set<String> selectedPackages;
  final Function(Set<String>) onSave;

  const AppSelectionScreen({
    super.key,
    required this.apps,
    required this.selectedPackages,
    required this.onSave,
  });

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  late Set<String> _tempSelected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelected = Set.from(widget.selectedPackages);
  }

  List<AppInfo> get _filteredApps {
    if (_searchQuery.isEmpty) return widget.apps;
    return widget.apps.where((app) => app.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kVoid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Приложения для VPN'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSave(_tempSelected);
              Navigator.pop(context);
            },
            child: const Text('Сохранить', style: TextStyle(color: kAccentCyan, fontWeight: FontWeight.w700)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: TextField(
                  style: const TextStyle(color: kTextPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    hintText: 'Поиск приложений...',
                    hintStyle: const TextStyle(color: kTextMuted),
                    prefixIcon: const Icon(Icons.search, color: kTextMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredApps.length,
        itemBuilder: (ctx, i) {
          final app = _filteredApps[i];
          final selected = _tempSelected.contains(app.packageName);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: selected ? kAccentPurple.withOpacity(0.10) : kGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? kAccentPurple.withOpacity(0.4) : kGlassBorder,
              ),
            ),
            child: CheckboxListTile(
              activeColor: kAccentPurple,
              checkColor: Colors.white,
              title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(app.packageName, style: const TextStyle(fontSize: 11, color: kTextMuted)),
              value: selected,
              onChanged: (v) {
                setState(() {
                  if (v == true) _tempSelected.add(app.packageName);
                  else _tempSelected.remove(app.packageName);
                });
              },
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  QR SCANNER SCREEN
// ═══════════════════════════════════════════════════════════
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;
      _handled = true;
      Navigator.pop(context, value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kVoid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Сканировать QR'),
        actions: [
          _GlassIconButton(icon: Icons.flash_on, onTap: () => _controller.toggleTorch()),
          _GlassIconButton(icon: Icons.cameraswitch, onTap: () => _controller.switchCamera()),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (ctx, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Камера недоступна:\n${error.errorDetails?.message ?? error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kTextSecondary),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: kAccentCyan.withOpacity(0.6), width: 2),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: kAccentCyan.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 40,
            child: Center(
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                radius: 24,
                child: const Text(
                  'Наведите на QR-код с VPN-ссылкой',
                  style: TextStyle(color: kTextSecondary, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}