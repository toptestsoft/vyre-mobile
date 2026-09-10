import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'services/vpn_service.dart';
import 'services/subscription_repository.dart';
import 'services/subscription_service.dart';
import 'services/subscription_cache.dart';
import 'services/update_service.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Импорты вынесенных модулей ───────────────────────────
import 'models/subscription.dart';          // ServerRow, SubscriptionItem
import 'models/vpn_state.dart';              // VpnState enum, ServerStatus, ParseResult
import 'utils/constants.dart';              // цвета, строки
import 'utils/helpers.dart';                // getUserFriendlyError
import 'widgets/glass_card.dart';           // GlassCard, GlassIconButton, AmbientOrb
import 'widgets/bento_status.dart';         // BentoStatus
import 'widgets/servers_sheet.dart';        // ServersSheet

// ═══════════════════════════════════════════════════════════
//  VYRE VPN — 2026 CYBER-GLASS AESTHETIC (fixed build)
// ═══════════════════════════════════════════════════════════

/// Бизнес-ошибка подписки: не проходит через getUserFriendlyError,
/// показывается пользователю как есть.
class SubException implements Exception {
  final String message;
  SubException(this.message);
  @override
  String toString() => message;
}

void main() {
  runApp(const VYREApp());
}

class VYREApp extends StatelessWidget {
  const VYREApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VYRE VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kVoid,
        // background/onBackground — deprecated, используем surface/onSurface
        colorScheme: const ColorScheme.dark(
          primary: kAccentCyan,
          secondary: kAccentPurple,
          surface: kSurface,
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
        dividerTheme: DividerThemeData(color: kGlassBorder, space: 1),
      ),
      home: const VYREHome(),
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
  late final VpnService _vpn;
  final TextEditingController _subController = TextEditingController();

  // ─── Состояние VPN ──────────────────────────────────────────
  List<ServerRow> _servers = [];
  String _error = '';
  VpnState _vpnState = VpnState.initializing;
  bool get _connected => _vpnState.isConnected;
  bool get _testing => _vpnState == VpnState.testing;
  bool get _isConnecting => _vpnState.isBusy;
  String get _statusText => _vpnLabel(_vpnState);

  String _vpnLabel(VpnState s) => switch (s) {
        VpnState.initializing => 'Инициализация…',
        VpnState.disconnected => 'Отключено',
        VpnState.testing => 'Проверка серверов…',
        VpnState.connecting => 'Подключение…',
        VpnState.connected => 'Подключено',
        VpnState.disconnecting => 'Отключение…',
        VpnState.error => 'Ошибка',
      };

  final SubscriptionRepository _repo = SubscriptionRepository();
  late final SubscriptionService _subs = SubscriptionService(_subCache);
  final SubscriptionCache _subCache = SubscriptionCache();
  bool _isInitialized = false;
  bool _disposed = false;       // 🔒 защита async-хвостов после dispose

  List<AppInfo> _allApps = [];
  Set<String> _vpnRoutedPackages = {}; // приложения, которые пускаем через VPN
  bool _appsLoaded = false;

  // ─── Подписки (с ID) ─────────────────────────────────────
  List<SubscriptionItem> _subscriptions = [];
  String? _activeSubscriptionId;

  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;

  SubscriptionItem? get _activeSub {
    if (_activeSubscriptionId == null) return null;
    for (final s in _subscriptions) {
      if (s.id == _activeSubscriptionId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _vpn = VpnService(
      onStateChanged: (state, raw) {
        if (!mounted) return;
        setState(() => _vpnState = state);
        _syncPulse();
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
    _loadPreferences();
  }

  @override
  void dispose() {
    _disposed = true;
    // ⚠️ ПРОДУКТОВОЕ РЕШЕНИЕ: VPN-туннель НЕ останавливаем при выходе с экрана.
    // Сервис flutter_v2ray живёт в фоне — пользователь ожидает, что VPN
    // продолжит работать после сворачивания приложения.
    // Если нужно гасить туннель вместе с UI — раскомментируйте:
    // if (_isInitialized) _v2ray.stopV2Ray();
    _pulseController.dispose();
    _glowController.dispose();
    _subController.dispose();
    super.dispose();
  }

  // ─── Единая загрузка настроек ─────────────────────────────
  Future<void> _loadPreferences() async {
    final subs = await _repo.loadAll();
    final id = await _repo.loadActiveId(subs);
    if (!mounted) return;
    setState(() {
      _subscriptions = subs;
      _activeSubscriptionId = id;
      if (id != null) {
        _subController.text = subs.firstWhere((s) => s.id == id).url;
      }
    });
  }

  Future<void> _initEngine() async {
    try {
      await _vpn.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = getUserFriendlyError(e));
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
      debugPrint('VYRE: не удалось загрузить список приложений: $e');
    }
  }

  void _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_packages', _vpnRoutedPackages.toList());
  }

  void _loadSavedSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('selected_packages');
    if (saved != null && mounted) {
      setState(() => _vpnRoutedPackages = saved.toSet());
    }
  }

  // ─── Подписки: единые точки изменения ──────────────────────
  void _saveSubscriptions() async {
    await _repo.saveAll(_subscriptions, _activeSubscriptionId);
  }

  void _activateSubscription(String id) {
    if (!_subscriptions.any((s) => s.id == id)) return;
    setState(() {
      _activeSubscriptionId = id;
      _subController.text = _subscriptions.firstWhere((s) => s.id == id).url;
    });
    _saveSubscriptions();
  }

  String _normalizeUrl(String u) {
    var s = u.trim();
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  void _addSubscription(String url) {
    final nu = _normalizeUrl(url);
    final existing = _subscriptions.where((s) => _normalizeUrl(s.url) == nu);
    if (existing.isNotEmpty) {
      _activateSubscription(existing.first.id);
      return;
    }
    final sub = SubscriptionItem(
      id: _generateId(),
      name: 'Подписка ${_subscriptions.length + 1}',
      url: url,
    );
    setState(() {
      _subscriptions.add(sub);
      _activeSubscriptionId = sub.id;
      _subController.text = url;
    });
    _saveSubscriptions();
  }

  void _removeSubscription(String id) {
    setState(() {
      _subscriptions.removeWhere((s) => s.id == id);
      if (_activeSubscriptionId == id) {
        _activeSubscriptionId = _subscriptions.isNotEmpty ? _subscriptions.first.id : null;
      }
      if (_activeSubscriptionId != null) {
        _subController.text =
            _subscriptions.firstWhere((s) => s.id == _activeSubscriptionId).url;
      } else {
        _subController.text = '';
      }
    });
    _saveSubscriptions();
  }

  // ─── Генерация ID (с разделителем, без коллизий склейки) ───
  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';


  /// Центральное управление пульсацией: безопасно при dispose и повторных вызовах.
  void _syncPulse() {
    if (!mounted || _disposed) return;
    try {
      final shouldAnimate = _testing || _connected;
      if (shouldAnimate && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      } else if (!shouldAnimate && _pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    } catch (_) {
      // контроллер мог быть уничтожен — игнорируем
    }
  }

  Future<void> _openTelegramChannel() async {
    final uri = Uri.parse('https://t.me/$kTelegramChannel');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        setState(() => _error = 'Не удалось открыть Telegram-канал');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = getUserFriendlyError(e));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.white)), backgroundColor: kDanger),
    );
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await UpdateService.checkForUpdates();

    if (updateInfo['error'] != null) {
      if (!mounted) return;
      _showError(updateInfo['error'] as String);
      return;
    }

    if (!updateInfo['hasUpdate']) {
      if (!mounted) return;
      _showError('У вас последняя версия');
      return;
    }

    final version = updateInfo['version'] as String;
    final releaseNotes = updateInfo['releaseNotes'] as String;
    final releaseUrl = updateInfo['releaseUrl'] as String;

    _showUpdateDialog(
      version: version,
      releaseNotes: releaseNotes,
      releaseUrl: releaseUrl,
    );
  }

  void _showUpdateDialog({
    required String version,
    required String releaseNotes,
    required String releaseUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0a0a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Доступно обновление', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Новая версия: $version', style: TextStyle(color: Colors.white)),
            SizedBox(height: 8),
            if (releaseNotes.isNotEmpty) ...[
              Text('Что нового:', style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                releaseNotes,
                style: TextStyle(color: kTextMuted, fontSize: 14),
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Позже', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(releaseUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (!mounted) return;
                _showError('Не удалось открыть страницу обновления');
              }
            },
            child: const Text('Обновить', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  void _showAboutApp() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = '${packageInfo.version}+${packageInfo.buildNumber}';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0a0a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [kAccentPurple, kAccentCyan],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kAccentPurple.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'V',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VYRE VPN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Cyber-Glass Edition',
                  style: TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Версия
            _buildInfoRow(
              icon: Icons.tag,
              iconColor: kAccentCyan,
              title: 'Версия',
              value: version,
            ),
            const SizedBox(height: 8),
            // Лицензия
            _buildInfoRow(
              icon: Icons.gavel,
              iconColor: kAccentPurple,
              title: 'Лицензия',
              value: 'MIT',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: kGlassBorder, height: 1),
            ),
            // Telegram
            _buildLinkRow(
              icon: Icons.telegram,
              iconColor: kAccentCyan,
              title: 'Telegram-канал',
              value: '@$kTelegramChannel',
              onTap: _openTelegramChannel,
            ),
            const SizedBox(height: 8),
            // GitHub
            _buildLinkRow(
              icon: Icons.code,
              iconColor: kAccentPurple,
              title: 'Исходный код',
              value: 'toptestsoft/vyre-mobile',
              onTap: () async { final uri = Uri.parse(kGithubUrl); if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); } },
            ),
            const SizedBox(height: 8),
            // Privacy
            _buildLinkRow(
              icon: Icons.privacy_tip_outlined,
              iconColor: kAccentMagenta,
              title: 'Политика конфиденциальности',
              value: 'github.com/toptestsoft/vyre-mobile',
              onTap: () async { final uri = Uri.parse(kGithubUrl); if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); } },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ОК', style: TextStyle(color: kAccentCyan)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: kAccentPurple.withValues(alpha: 0.2),
              foregroundColor: kAccentPurple,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _checkForUpdates();
            },
            icon: const Icon(Icons.system_update, size: 18),
            label: const Text('Проверить обновления'),
          ),
        ],
      ),
    );
  }

  // Строка информации (без нажатия)
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGlassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: kTextSecondary, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Строка-ссылка (с нажатием)
  Widget _buildLinkRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kGlass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGlassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: kTextSecondary, fontSize: 12),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: kTextMuted,
            ),
          ],
        ),
      ),
    );
  }



  // ─── Основной метод подключения ───────────────────────────
  Future<void> _connect() async {
    if (!mounted || _isConnecting) return;
    setState(() {
      _error = '';
      _servers = [];
      _vpnState = VpnState.testing;
    });

    if (!_isInitialized) {
      setState(() {
        _error = 'Движок не инициализирован';
      });
      return;
    }

    final subUrl = _subController.text.trim();
    if (subUrl.isEmpty) {
      setState(() {
        _error = 'Введите ссылку подписки';
      });
      return;
    }

    // Единая точка сохранения/активации подписки
    _addSubscription(subUrl);

    try {
      setState(() { _vpnState = VpnState.testing; });
      _syncPulse();

      final bool isSingle = SubscriptionService.isSingleLink(subUrl);
      final lower = subUrl.toLowerCase();
      String body;

      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        body = await _subs.fetch(subUrl);
      } else {
        body = subUrl;
      }

      final List<V2RayURL> parsed = _subs.parseToV2RayUrls(body, isSingleLink: isSingle);
      if (parsed.isEmpty) {
        throw SubException('Подписка не содержит серверов');
      }

      // ─── Тестируем серверы, не более 5 одновременно ────
      final List<ServerRow> rows = [];
      final List<Future<void>> futures = [];
      final semaphore = Semaphore(5);

      for (final p in parsed) {
        futures.add(
          semaphore.withPermit(() async {
            final cfg = p.getFullConfiguration();
            int ms = -1;
            try {
              ms = await _vpn.pingServer(cfg);
            } catch (_) {}
            rows.add(ServerRow(remark: p.remark, config: cfg, delayMs: ms));
          }),
        );
      }

      await Future.wait(futures);

      // ─── Сортировка: сначала успешные, потом остальные ────
      final valid = rows.where((r) => r.delayMs >= 0).toList()
        ..sort((a, b) => a.delayMs.compareTo(b.delayMs));
      final invalid = rows.where((r) => r.delayMs < 0).toList();
      final sortedRows = [...valid, ...invalid];

      if (!mounted) return;
      setState(() {
        _servers = sortedRows;
        _vpnState = VpnState.disconnected;
      });
      _syncPulse();

      // ─── Выбираем лучший сервер ──────
      final ServerRow best = valid.isNotEmpty
          ? valid.first
          : rows.firstWhere((r) => r.config.isNotEmpty, orElse: () => rows.first);

      // ─── Split-tunneling: guard от пустого списка приложений ──────
      List<String>? blockedAppsList;
      if (_vpnRoutedPackages.isNotEmpty && _appsLoaded && _allApps.isNotEmpty) {
        blockedAppsList = _allApps
            .map((app) => app.packageName)
            .where((pkg) => !_vpnRoutedPackages.contains(pkg))
            .toList();
      }

      final granted = await _vpn.requestPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _error = 'Нет прав на VPN (отклонено)';
          _vpnState = VpnState.error;
        });
        return;
      }

      setState(() { _vpnState = VpnState.connecting; });
      await _vpn.connect(
        remark: best.remark.isEmpty ? 'VYRE' : best.remark,
        config: best.config,
        blockedApps: blockedAppsList,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is SubException ? e.message : getUserFriendlyError(e);
        _vpnState = VpnState.error;
      });
      _syncPulse();
    } finally {
      if (mounted) setState(() { _vpnState = VpnState.disconnected; });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _vpn.disconnect();
      _syncPulse();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = getUserFriendlyError(e));
    }
  }

  // ─── QR-сканер ─────────────────────────────────────────────
  Future<void> _openQrScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _subController.text = result;
        _error = '';
      });
    }
  }

  // ─── Выбор приложений ──────────────────────────────────────
  void _openAppSelection() async {
    if (!_appsLoaded) await _loadAppsIfNeeded();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppSelectionScreen(
          apps: _allApps,
          selectedPackages: _vpnRoutedPackages,
          onSave: (selected) {
            setState(() => _vpnRoutedPackages = selected);
            _saveSelection();
          },
        ),
      ),
    );
  }

  // ─── Управление подписками ────────────────────────────────
  void _showManageSubscriptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubscriptionsSheet(
        subscriptions: _subscriptions,
        activeId: _activeSubscriptionId,
        onSelect: (id) => _activateSubscription(id),
        onAdd: (url) => _addSubscription(url),
        onDelete: (id) => _removeSubscription(id),
      ),
    );
  }

  void _showServersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ServersSheet(servers: _servers),
    );
  }

  // ─── Вставка из буфера ────────────────────────────────────
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      setState(() => _subController.text = data!.text!);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final statusColor = _connected ? kSuccess : kDanger;
    final statusGlow = _connected ? kGlowCyan : kGlowPurple;
    final bool canStart = !_connected && !_testing && !_isConnecting && _isInitialized;

    return Scaffold(
      backgroundColor: kVoid,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0a0a1a),
                    Color(0xFF1a1a3a),
                    Color(0xFF2d1f6e),
                    Color(0xFF7c4dff),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF7c4dff).withValues(alpha: 0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7c4dff).withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Text('V', style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                )),
              ),
            ),
            const SizedBox(width: 8),
            const Text('VYRE', style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 1,
              color: Colors.white,
            )),
          ],
        ),
        actions: [
          GlassIconButton(icon: Icons.qr_code_scanner, onTap: _openQrScanner),
          GlassIconButton(icon: Icons.apps, onTap: _openAppSelection),
          GlassIconButton(
            icon: Icons.telegram,
            onTap: _openTelegramChannel,
            tooltip: 'Подписка в Telegram',
          ),
          GlassIconButton(
            icon: Icons.info_outline,
            onTap: _showAboutApp,
            tooltip: 'О приложении',
          ),
          GlassIconButton(
            icon: Icons.more_vert,
            onTap: _showManageSubscriptions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: AmbientOrb(
              size: 300,
              color: _connected ? kAccentCyan.withValues(alpha: 0.12) : kAccentPurple.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: AmbientOrb(
              size: 250,
              color: _connected ? kAccentPurple.withValues(alpha: 0.08) : kAccentMagenta.withValues(alpha: 0.06),
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
                    BentoStatus(
                      connected: _connected,
                      statusText: _statusText,
                      selectedCount: _vpnRoutedPackages.length,
                      serverCount: _servers.length,
                      activeSub: _activeSub?.name,
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_pulseAnim, _glowAnim]),
                        builder: (context, child) {
                          final isPulsing = _testing || _connected;
                          final scale = isPulsing ? _pulseAnim.value : 1.0;
                          return Semantics(
                            button: true,
                            label: _connected ? 'Отключиться от VPN' : 'Подключиться к VPN',
                            enabled: _connected || canStart,
                            child: GestureDetector(
                              onTap: _connected ? _disconnect : (canStart ? _connect : null),
                            child: SizedBox(
                              width: 220,
                              height: 220,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 220 * scale,
                                    height: 220 * scale,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          statusGlow.withValues(alpha: _glowAnim.value),
                                          statusGlow.withValues(alpha: 0.0),
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
                                            ? [
                                                kAccentCyan.withValues(alpha: 0.3),
                                                kAccentPurple.withValues(alpha: 0.2),
                                              ]
                                            : [kSurfaceLight, kSurface],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: _connected ? kAccentCyan.withValues(alpha: 0.4) : kGlassBorder,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusColor.withValues(alpha: 0.25),
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
                          ),
                        );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
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
                                  fillColor: Colors.white.withValues(alpha: 0.03),
                                  hintText: 'https://... или vless://',
                                  hintStyle: const TextStyle(color: kTextMuted),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.content_paste, size: 20, color: kTextSecondary),
                                        onPressed: _pasteFromClipboard,
                                        tooltip: 'Вставить',
                                      ),
                                    ],
                                  ),
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
                                    Text(
                                      '${_servers.length} найдено · Лучший: ${_servers.first.delayMs >= 0 ? '${_servers.first.delayMs} мс' : 'N/A'}',
                                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                                    ),
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
                        tint: Colors.white.withValues(alpha: 0.02),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off, color: kTextMuted.withValues(alpha: 0.5), size: 24),
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

// ─── Semaphore: корректный ограничитель параллелизма ────────
class Semaphore {
  final int maxConcurrency;
  int _current = 0;
  final List<Completer<void>> _queue = [];

  Semaphore(this.maxConcurrency);

  Future<void> withPermit(Future<void> Function() action) async {
    // while (а не if): проснувшись, перепроверяем свободен ли слот
    while (_current >= maxConcurrency) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }
    _current++;
    try {
      await action();
    } finally {
      _current--;
      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete();
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  SUBSCRIPTIONS SHEET
// ═══════════════════════════════════════════════════════════
class _SubscriptionsSheet extends StatefulWidget {
  final List<SubscriptionItem> subscriptions;
  final String? activeId;
  final Function(String) onSelect;
  final Function(String) onAdd;
  final Function(String) onDelete;

  const _SubscriptionsSheet({
    required this.subscriptions,
    required this.activeId,
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
                color: kSurface.withValues(alpha: 0.9),
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
                        final isActive = widget.activeId == s.id;
                        return GestureDetector(
                          onTap: () {
                            widget.onSelect(s.id);
                            Navigator.pop(context);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isActive ? kAccentPurple.withValues(alpha: 0.12) : kGlass,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isActive ? kAccentPurple.withValues(alpha: 0.4) : kGlassBorder,
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
                                    showDialog(
                                      context: ctx,
                                      barrierColor: Colors.black.withValues(alpha: 0.6),
                                      builder: (ctx2) => AlertDialog(
                                        backgroundColor: const Color(0xFF0a0a1a),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text('Удалить подписку?', style: TextStyle(color: Colors.white)),
                                        content: Text('${s.name}\n${s.url}', style: const TextStyle(color: kTextSecondary)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Отмена', style: TextStyle(color: kTextMuted))),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(ctx2);
                                              widget.onDelete(s.id);
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Удалить', style: TextStyle(color: kDanger)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: kDanger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
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
//  APP SELECTION SCREEN (с debounce поиска)
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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tempSelected = Set.from(widget.selectedPackages);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  List<AppInfo> get _filteredApps {
    if (_searchQuery.isEmpty) return widget.apps;
    final q = _searchQuery.toLowerCase();
    return widget.apps.where((app) =>
        app.name.toLowerCase().contains(q) ||
        app.packageName.toLowerCase().contains(q)
    ).toList();
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
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    hintText: 'Поиск приложений...',
                    hintStyle: const TextStyle(color: kTextMuted),
                    prefixIcon: const Icon(Icons.search, color: kTextMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 250), () {
                      if (mounted) setState(() => _searchQuery = v);
                    });
                  },
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
              color: selected ? kAccentPurple.withValues(alpha: 0.10) : kGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? kAccentPurple.withValues(alpha: 0.4) : kGlassBorder,
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
                  if (v == true) {
                    _tempSelected.add(app.packageName);
                  } else {
                    _tempSelected.remove(app.packageName);
                  }
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
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  static const List<String> _validSchemes = [
    'vless://', 'vmess://', 'trojan://', 'ss://', 'socks://',
    'hy2://', 'hysteria2://', 'http://', 'https://',
  ];

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
      if (_validSchemes.any((s) => value.startsWith(s))) {
        _handled = true;
        Navigator.pop(context, value);
        return;
      }
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
          GlassIconButton(icon: Icons.flash_on, onTap: () => _controller.toggleTorch()),
          GlassIconButton(icon: Icons.cameraswitch, onTap: () => _controller.switchCamera()),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (ctx, error, child) => Center(
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
                border: Border.all(color: kAccentCyan.withValues(alpha: 0.6), width: 2),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: kAccentCyan.withValues(alpha: 0.15),
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