import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/services.dart';
import 'services/vpn_service.dart';
import 'services/subscription_repository.dart';
import 'services/subscription_service.dart';
import 'services/subscription_storage.dart';
import 'services/subscription_cache.dart';
import 'services/update_service.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ─── Импорты вынесенных модулей ───────────────────────────
import 'models/subscription.dart';          // ServerRow, SubscriptionItem
import 'utils/constants.dart';              // цвета, строки
import 'utils/helpers.dart';                // getUserFriendlyError, SubException
import 'widgets/glass_card.dart';           // GlassCard, GlassIconButton, AmbientOrb
import 'widgets/connection_status_panel.dart'; // ConnectionStatusPanel
import 'widgets/subscription_card.dart';    // SubscriptionCard
import 'widgets/start_button.dart';         // StartButton
import 'controllers/subscription_controller.dart'; // SubscriptionController

// ═══════════════════════════════════════════════════════════
//  VYRE VPN — 2026 CYBER-GLASS AESTHETIC (fixed build)
// ═══════════════════════════════════════════════════════════

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
  late SubscriptionController _controller;

  final SubscriptionRepository _repo = SubscriptionRepository();
  late final SubscriptionService _subs = SubscriptionService(_subCache);
  final SubscriptionCache _subCache = SubscriptionCache();
  late DefaultSubscriptionStorage _subStorage;
  SubscriptionStorageState? _subscriptionStorageState;
  bool _showStorageBanner = false;

  List<AppInfo> _allApps = [];
  Set<String> _vpnRoutedPackages = {}; // приложения, которые пускаем через VPN
  bool _appsLoaded = false;

  // ─── Подписки (с ID) ─────────────────────────────────────
  List<SubscriptionItem> _subscriptions = [];
  String? _activeSubscriptionId;

  @override
  void initState() {
    super.initState();
    _vpn = VpnService(
      onStateChanged: (state, raw) {
        if (!mounted) return;
        _controller.updateVpnState(state);
      },
    );

    _controller = SubscriptionController(
      vpnService: _vpn,
      inputController: _subController,
      subscriptionService: _subs,
      qrScannerBuilder: (_) => const QrScannerScreen(),
    );

    _controller.initialize();
    _loadAppsIfNeeded();
    _loadSavedSelection();
    _loadPreferences();
    _detectStorageState();
  }

  @override
  void dispose() {
    // ⚠️ ПРОДУКТОВОЕ РЕШЕНИЕ: VPN-туннель НЕ останавливаем при выходе с экрана.
    // Сервис flutter_v2ray живёт в фоне — пользователь ожидает, что VPN
    // продолжит работать после сворачивания приложения.
    // Если нужно гасить туннель вместе с UI — раскомментируйте:
    // if (_vpnState != VpnState.disconnected) _v2ray.stopV2Ray();
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

  Future<void> _detectStorageState() async {
    try {
      _subStorage = DefaultSubscriptionStorage(
        secure: FlutterSecureStorageAdapter(),
        prefs: await SharedPreferences.getInstance(),
      );
      final state = await _subStorage.readState();
      if (!mounted) return;
      setState(() {
        _subscriptionStorageState = state;
        if (state.isStorageLoss) {
          _showStorageBanner = true;
        } else if (state.status == SubscriptionStorageStatus.anomaly) {
          debugPrint('VYRE: subscription storage anomaly — secret exists but imported=false');
        }
      });
    } catch (e) {
      debugPrint('VYRE: failed to detect subscription storage state: $e');
    }
  }

  void _dismissStorageBanner() {
    setState(() => _showStorageBanner = false);
    if (_subscriptionStorageState?.status == SubscriptionStorageStatus.storageLoss) {
      _subStorage.writeMetadata(imported: false);
    }
  }

  void _focusSubscriptionField() {
    FocusScope.of(context).requestFocus(FocusNode());
    _subController.selection = TextSelection(baseOffset: 0, extentOffset: _subController.text.length);
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.white)), backgroundColor: kDanger),
    );
  }

  Future<void> _openTelegramChannel() async {
    final uri = Uri.parse('https://t.me/$kTelegramChannel');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть Telegram-канал'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getUserFriendlyError(e)), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await UpdateService.checkForUpdates();

    if (updateInfo.error != null) {
      if (!mounted) return;
      _showError(updateInfo.error!);
      return;
    }

    if (!updateInfo.hasUpdate) {
      if (!mounted) return;
      _showError('У вас последняя версия');
      return;
    }

    _showUpdateDialog(
      version: updateInfo.version,
      releaseNotes: updateInfo.releaseNotes,
      downloadUrl: updateInfo.downloadUrl ?? '',
    );
  }

  void _showUpdateDialog({
    required String version,
    required String releaseNotes,
    required String downloadUrl,
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
              final uri = Uri.parse(downloadUrl);
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

  Future<void> _showSettings() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0a0a1a),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.apps,
              title: 'Приложения',
              onTap: () {
                Navigator.pop(ctx);
                _openAppSelection();
              },
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.list_alt,
              title: 'Подписки',
              onTap: () {
                Navigator.pop(ctx);
                _showManageSubscriptions();
              },
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.telegram,
              title: 'Telegram-канал',
              iconColor: kAccentCyan,
              onTap: () {
                Navigator.pop(ctx);
                _openTelegramChannel();
              },
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'Информация',
              onTap: () {
                Navigator.pop(ctx);
                _showAboutApp();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
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
        contentPadding: const EdgeInsets.fromLTRB(12, kSpace4, 12, 12),
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
            Expanded(
              child: Column(
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
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, color: kTextSecondary, size: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Версия
            _buildInfoRow(
              icon: Icons.tag,
              iconColor: kAccentPurple,
              title: 'Версия',
              value: version,
            ),
            const SizedBox(height: kSpace2),
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
            // GitHub
            _buildLinkRow(
              icon: Icons.code,
              iconColor: kAccentCyan,
              title: 'Исходный код',
              value: 'toptestsoft/vyre-mobile',
              onTap: () async { final uri = Uri.parse(kGithubUrl); if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); } },
            ),
            const SizedBox(height: kSpace2),
            // Telegram
            _buildLinkRow(
              icon: Icons.telegram,
              iconColor: kAccentCyan,
              title: 'Telegram-канал',
              value: '@$kTelegramChannel',
              onTap: _openTelegramChannel,
            ),
            const SizedBox(height: kSpace2),
            // Privacy
            _buildLinkRow(
              icon: Icons.privacy_tip_outlined,
              iconColor: kAccentCyan,
              title: 'Политика конфиденциальности',
              value: 'github.com/toptestsoft/vyre-mobile',
              onTap: () async { final uri = Uri.parse(kGithubUrl); if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); } },
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccentPurple,
              side: const BorderSide(color: kGlassBorder),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    if (!mounted || _controller.isBusy) return;

    final subUrl = _subController.text.trim();
    if (!_controller.validateInput(subUrl)) return;

    _addSubscription(subUrl);

    List<String>? blockedAppsList;
    if (_vpnRoutedPackages.isNotEmpty && _appsLoaded && _allApps.isNotEmpty) {
      blockedAppsList = _allApps
          .map((app) => app.packageName)
          .where((pkg) => !_vpnRoutedPackages.contains(pkg))
          .toList();
    }

    try {
      await _controller.loadAndTest(subUrl);
      if (_controller.allServersUnavailable) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Серверы недоступны'),
            content: const Text('Все серверы не ответили на ping. Проверьте подключение к интернету и попробуйте снова.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
        return;
      }

      if (_controller.error.isNotEmpty) return;
      if (!mounted) return;
      await _controller.connect(context, blockedApps: blockedAppsList);
    } catch (e) {
      // error уже установлен в контроллере
    }
  }

  Future<void> _disconnect() async {
    await _controller.disconnect();
  }

  Future<void> _cancelTesting() async {
    await _controller.cancel();
  }

  // ─── QR-сканер ─────────────────────────────────────────────
  Future<void> _openQrScanner() async {
    final result = await _controller.scanQr(context);
    if (result != null && result.isNotEmpty && mounted) {
      _controller.updateInput(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Подписка добавлена'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
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

  // ─── Вставка из буфера ────────────────────────────────────
  Future<void> _pasteFromClipboard() async {
    final text = await _controller.paste();
    if (!mounted) return;
    if (text != null && text.isNotEmpty) {
      _controller.updateInput(text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Подписка добавлена в поле. Нажмите СТАРТ для подключения.'),
          backgroundColor: kSuccess,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Буфер обмена пуст'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final bool canStart = _controller.vpnState.canStart;

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
              GlassIconButton(icon: Icons.settings, onTap: _showSettings),
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
                  color: _controller.isConnected ? kAccentCyan.withValues(alpha: 0.12) : kAccentPurple.withValues(alpha: 0.10),
                ),
              ),
              Positioned(
                bottom: -80,
                right: -80,
                child: AmbientOrb(
                  size: 250,
                  color: _controller.isConnected ? kAccentPurple.withValues(alpha: 0.08) : kAccentMagenta.withValues(alpha: 0.06),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              if (_showStorageBanner && _subscriptionStorageState != null)
                                _StorageLossBanner(
                                  onImport: _focusSubscriptionField,
                                  onDismiss: _dismissStorageBanner,
                                ),
                              SubscriptionCard(
                                controller: _subController,
                                onPaste: _pasteFromClipboard,
                                onScanQr: _openQrScanner,
                                isTesting: _controller.isTesting,
                                onChanged: (_) => _controller.dismissError(),
                              ),
                              const SizedBox(height: kSpace4),
                              StartButton(
                                vpnState: _controller.vpnState,
                                isConnected: _controller.isConnected,
                                canStart: canStart,
                                onStart: _connect,
                                onStop: _disconnect,
                                onCancel: _cancelTesting,
                              ),
                              const SizedBox(height: kSpace3),
                              ConnectionStatusPanel(
                                vpnState: _controller.vpnState,
                                notice: _controller.notice.isEmpty ? null : _controller.notice,
                                error: _controller.error.isEmpty ? null : _controller.error,
                                serversCount: _controller.servers.length,
                                bestDelayMs: _controller.bestDelayMs,
                                connectedServer: _controller.connectedServer,
                                connectedProtocol: _controller.connectedProtocol,
                                hasSubscription: _subController.text.isNotEmpty,
                              ),
                              const SizedBox(height: kSpace3),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _StorageLossBanner extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onDismiss;

  const _StorageLossBanner({
    required this.onImport,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: kSpace3),
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          const SizedBox(width: kSpace2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Подписка не читается',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Зашифрованное хранилище было сброшено или повреждено, например после переустановки приложения. '
                      'Данные подписки восстановить невозможно, импортируйте ссылку заново.',
                  style: const TextStyle(fontSize: 12, color: kTextSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpace2),
          TextButton(
            onPressed: onImport,
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Импортировать заново'),
          ),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: kTextMuted,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
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
    final hasChanges = _tempSelected.length != widget.selectedPackages.length ||
        !_tempSelected.containsAll(widget.selectedPackages) ||
        !widget.selectedPackages.containsAll(_tempSelected);

    return Scaffold(
      backgroundColor: kVoid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Приложения для VPN'),
            Text(
              'Выбрано: ${_tempSelected.length}',
              style: const TextStyle(color: kTextMuted, fontSize: 12),
            ),
          ],
        ),
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
        actions: [
          if (_tempSelected.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _tempSelected = {});
              },
              child: const Text('Снять всё', style: TextStyle(color: kTextMuted)),
            ),
          TextButton(
            onPressed: hasChanges
                ? () {
                    widget.onSave(_tempSelected);
                    Navigator.pop(context);
                  }
                : null,
            child: Text(
              'Сохранить',
              style: TextStyle(
                color: hasChanges ? kAccentCyan : kTextMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredApps.length,
        itemBuilder: (ctx, i) {
          final app = _filteredApps[i];
          final selected = _tempSelected.contains(app.packageName);
          return InkWell(
            onTap: () {
              setState(() {
                if (selected) {
                  _tempSelected.remove(app.packageName);
                } else {
                  _tempSelected.add(app.packageName);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? kAccentPurple.withValues(alpha: 0.10) : kGlass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? kAccentPurple.withValues(alpha: 0.4) : kGlassBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kAccentPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        app.name.isNotEmpty ? app.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.packageName,
                          style: const TextStyle(fontSize: 11, color: kTextMuted),
                        ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    ignoring: true,
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) {},
                      activeColor: kAccentPurple,
                      checkColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
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
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: kGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGlassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kGlass,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGlassBorder),
              ),
              child: Icon(icon, color: iconColor ?? kTextSecondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

  DateTime? _lastFeedbackTime;

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

    final now = DateTime.now();
    if (_lastFeedbackTime == null || now.difference(_lastFeedbackTime!) > const Duration(seconds: 2)) {
      _lastFeedbackTime = now;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Неподдерживаемый формат QR-кода'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
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