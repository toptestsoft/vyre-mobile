import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../models/vpn_state.dart';
import '../models/subscription.dart';
import '../services/vpn_service.dart';
import '../services/subscription_service.dart';
import '../services/config_validator.dart';
import '../services/config_normalizer.dart';
import '../services/server_selector.dart';
import '../utils/helpers.dart';
import '../utils/semaphore.dart';

class SubscriptionController extends ChangeNotifier {
  final VpnService vpnService;
  final TextEditingController inputController;
  final SubscriptionService subscriptionService;
  final WidgetBuilder qrScannerBuilder;

  // Состояние подписки
  VpnState _vpnState = VpnState.initializing;
  List<ServerRow> _servers = [];
  String _error = '';
  String _notice = '';
  String? _connectedServer;
  String? _connectedProtocol;
  bool _cancelRequested = false;
  SubscriptionItem? _activeSub;

  SubscriptionController({
    required this.vpnService,
    required this.inputController,
    required this.subscriptionService,
    required this.qrScannerBuilder,
  });

  // ─── Геттеры ──────────────────────────────────────────────
  VpnState get vpnState => _vpnState;
  bool get isConnected => _vpnState.isConnected;
  bool get isTesting => _vpnState == VpnState.testing;
  bool get isBusy => _vpnState.isBusy;
  List<ServerRow> get servers => List.unmodifiable(_servers);
  String get error => _error;
  String get notice => _notice;
  String? get connectedServer => _connectedServer;
  String? get connectedProtocol => _connectedProtocol;
  SubscriptionItem? get activeSub => _activeSub;
  int? get bestDelayMs {
    if (_servers.isEmpty) return null;
    final positive = _servers.where((s) => s.delayMs >= 0).toList();
    if (positive.isEmpty) return null;
    return positive.map((s) => s.delayMs).reduce((a, b) => a < b ? a : b);
  }

  bool get allServersUnavailable =>
      _error == 'Все серверы не ответили на ping' && _servers.isNotEmpty;

  // ─── Действия ─────────────────────────────────────────────
  void updateInput(String text) {
    inputController.text = text;
    if (_error.isNotEmpty) {
      _error = '';
      notifyListeners();
    }
  }

  void dismissError() {
    if (_error.isNotEmpty) {
      _error = '';
      notifyListeners();
    }
  }

  Future<String?> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  Future<String?> scanQr(BuildContext context) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: qrScannerBuilder),
    );
    return result;
  }

  bool validateInput(String url) {
    if (url.trim().isEmpty) {
      _error = 'Введите ссылку подписку';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> initialize() async {
    try {
      await vpnService.initialize();
      _vpnState = VpnState.disconnected;
      notifyListeners();
    } catch (e) {
      _error = getUserFriendlyError(e);
      _vpnState = VpnState.disconnected;
      notifyListeners();
    }
  }

  Future<void> loadAndTest(String url) async {
    if (url.trim().isEmpty) {
      _error = 'Введите ссылку подписку';
      notifyListeners();
      return;
    }

    _error = '';
    _servers = [];
    _vpnState = VpnState.testing;
    _cancelRequested = false;
    notifyListeners();

    try {
      final bool isSingle = SubscriptionService.isSingleLink(url);
      final lower = url.toLowerCase();
      String body;

      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        body = await subscriptionService.fetch(url);
      } else {
        body = url;
      }

      final List<V2RayURL> parsed = subscriptionService.parseToV2RayUrls(
        body,
        isSingleLink: isSingle,
      );
      if (parsed.isEmpty) {
        throw SubException('Подписка не содержит серверов');
      }

      // Валидация конфигов перед пингом
      final validator = ConfigValidator();
      final List<V2RayURL> validParsed = [];
      int invalidCount = 0;

      for (final p in parsed) {
        try {
          final cfg = p.getFullConfiguration();
          validator.validate(jsonDecode(cfg));
          validParsed.add(p);
        } on ConfigValidationException {
          invalidCount++;
        } catch (_) {
          invalidCount++;
        }
      }

      if (validParsed.isEmpty) {
        _error = 'Все серверы в подписке невалидны';
        _vpnState = VpnState.disconnected;
        notifyListeners();
        return;
      }

      if (invalidCount > 0) {
        _notice = 'Отфильтровано невалидных серверов: $invalidCount';
        notifyListeners();
      }

      // Тестируем серверы, не более 5 одновременно
      final List<ServerRow> rows = [];
      final List<Future<void>> futures = [];
      final semaphore = Semaphore(5);

      for (final p in validParsed) {
        futures.add(
          semaphore.withPermit(() async {
            if (_cancelRequested) return;
            final rawCfg = p.getFullConfiguration();
            try {
              final cfg = ConfigNormalizer().normalize(rawCfg);
              int ms = -1;
              try {
                ms = await vpnService.pingServer(cfg);
              } catch (_) {}
              rows.add(ServerRow(remark: p.remark, config: cfg, delayMs: ms));
            } on ConfigNormalizationException {
              // сервер отклонён нормализатором
            }
          }),
        );
      }

      try {
        await Future.wait(futures).timeout(const Duration(seconds: 30));
      } on TimeoutException {
        // продолжаем с тем, что успело собраться
      }

      final selector = ServerSelector();
      final sortedRows = selector.sort(rows);

      _servers = sortedRows;
      _vpnState = VpnState.disconnected;
      notifyListeners();

      // Выбираем лучший сервер
      final ServerRow? bestCandidate = selector.selectBest(sortedRows);
      final ServerRow best = bestCandidate ??
          rows.firstWhere((r) => r.config.isNotEmpty, orElse: () => rows.first);

      _connectedServer = best.remark.isEmpty ? 'VYRE' : best.remark;
      _connectedProtocol = _extractProtocol(best.config);
      _notice = '';
      notifyListeners();

      if (bestCandidate == null) {
        _error = 'Все серверы не ответили на ping';
        notifyListeners();
        return;
      }
    } catch (e) {
      _error = e is SubException ? e.message : getUserFriendlyError(e);
      _vpnState = VpnState.disconnected;
      notifyListeners();
    }
  }

  Future<void> connect(BuildContext? context, {List<String>? blockedApps}) async {
    if (_servers.isEmpty) {
      _error = 'Нет серверов для подключения';
      notifyListeners();
      return;
    }

    try {
      _notice = '';
      _vpnState = VpnState.connecting;
      notifyListeners();

      final best = _servers.firstWhere(
        (s) => s.delayMs >= 0,
        orElse: () => _servers.first,
      );

      final granted = await vpnService.requestPermission();
      if (context == null || !context.mounted) return;
      if (!granted) {
        _error = 'Нет прав на VPN (отклонено)';
        _vpnState = VpnState.disconnected;
        notifyListeners();
        return;
      }

      await vpnService.connect(
        remark: best.remark.isEmpty ? 'VYRE' : best.remark,
        config: best.config,
        blockedApps: blockedApps ?? const [],
      );
    } catch (e) {
      _error = e is SubException ? e.message : getUserFriendlyError(e);
      _vpnState = VpnState.disconnected;
      _connectedServer = null;
      _connectedProtocol = null;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await vpnService.disconnect();
    } catch (e) {
      _error = getUserFriendlyError(e);
    } finally {
      _connectedServer = null;
      _connectedProtocol = null;
      _notice = '';
      _vpnState = VpnState.disconnected;
      notifyListeners();
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    _vpnState = VpnState.disconnected;
    _notice = 'Тестирование отменено';
    notifyListeners();
  }

  void updateVpnState(VpnState state) {
    _vpnState = state;
    notifyListeners();
  }

  String? _extractProtocol(String config) {
    if (config.isEmpty) return null;
    final lower = config.toLowerCase();
    if (lower.startsWith('vless://')) return 'VLESS';
    if (lower.startsWith('vmess://')) return 'VMess';
    if (lower.startsWith('trojan://')) return 'Trojan';
    if (lower.startsWith('ss://')) return 'Shadowsocks';
    return null;
  }
}
