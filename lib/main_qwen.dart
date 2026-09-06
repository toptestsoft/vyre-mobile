import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════
// CYBERPUNK NEON COLOR SCHEME
// ═══════════════════════════════════════════════════════════════
const Color cyberBlack = Color(0xFF0A0A0F);
const Color cyberDark = Color(0xFF12121A);
const Color cyberPurple = Color(0xFFBD00FF);
const Color cyberCyan = Color(0xFF00F0FF);
const Color cyberPink = Color(0xFFFF006E);
const Color cyberGreen = Color(0xFF39FF14);
const Color cyberYellow = Color(0xFFFFEA00);

void main() {
  runApp(const VeilApp());
}

class VeilApp extends StatelessWidget {
  const VeilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veil VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: cyberPurple,
          brightness: Brightness.dark,
        ).copyWith(
          primary: cyberPurple,
          surface: cyberDark,
        ),
        scaffoldBackgroundColor: cyberBlack,
        appBarTheme: const AppBarTheme(
          backgroundColor: cyberBlack,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const VeilHome(),
    );
  }
}

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

class VeilHome extends StatefulWidget {
  const VeilHome({super.key});

  @override
  State<VeilHome> createState() => _VeilHomeState();
}

class _VeilHomeState extends State<VeilHome> with SingleTickerProviderStateMixin {
  late final FlutterV2ray _vless;
  late AnimationController _pulseController;
  final TextEditingController _subController = TextEditingController(text: 'https://');

  bool _connected = false;
  String _statusText = 'Отключено';
  List<ServerRow> _servers = [];
  String _error = '';
  bool _testing = false;
  bool _isInitialized = false;
  bool _isConnecting = false;

  List<AppInfo> _allApps = [];
  Set<String> _selectedPackages = {};
  bool _appsLoaded = false;

  List<SubscriptionItem> _subscriptions = [];
  int _activeSubIndex = -1;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _vless = FlutterV2ray(
      onStatusChanged: (status) {
        setState(() {
          _connected = status.state == 'CONNECTED';
          _statusText = _connLabel(status.state);
          if (_connected) {
            _pulseController.repeat(reverse: true);
          } else {
            _pulseController.stop();
          }
        });
      },
    );
    _initEngine();
    _loadAppsIfNeeded();
    _loadSavedSelection();
    _bootstrap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _vless.stopV2Ray();
    _subController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('subscriptions');
    if (savedList != null && savedList.isNotEmpty) {
      await _loadSubscriptions();
      _loadActiveSubIndex();
      await _tryAutoConnect();
      return;
    }
    final oldUrl = prefs.getString('subscription_url');
    if (oldUrl != null && oldUrl.isNotEmpty) {
      setState(() {
        _subscriptions = [SubscriptionItem(name: 'Подписка 1', url: oldUrl)];
        _activeSubIndex = 0;
        _subController.text = oldUrl;
      });
      await prefs.setStringList(
        'subscriptions',
        _subscriptions.map((s) => json.encode(s.toJson())).toList(),
      );
      await prefs.setInt('active_sub_index', 0);
      await prefs.remove('subscription_url');
    }
    await _tryAutoConnect();
  }

  Future<void> _tryAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final wasAuto = prefs.getBool('auto_connect') ?? false;
    if (!wasAuto) return;
    if (_activeSubIndex < 0 || _activeSubIndex >= _subscriptions.length) return;
    if (_isInitialized && !_connected) {
      await Future.delayed(const Duration(milliseconds: 500));
      _connect();
    }
  }

  Future<void> _initEngine() async {
    try {
      await _vless.initializeV2Ray();
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _error = _getUserFriendlyError(e));
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
      setState(() {
        _allApps = apps;
        _appsLoaded = true;
      });
    } catch (e) {
      setState(() => _error = 'Не удалось загрузить приложения: $e');
    }
  }

  void _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_packages', _selectedPackages.toList());
  }

  void _loadSavedSelection() async {}

  void _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _subscriptions.map((s) => json.encode(s.toJson())).toList();
    await prefs.setStringList('subscriptions', jsonList);
  }

  Future<void> _loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('subscriptions') ?? [];
    final subs = jsonList.map((j) => SubscriptionItem.fromJson(json.decode(j))).toList();
    setState(() => _subscriptions = subs);
  }

  void _saveActiveSubIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_sub_index', _activeSubIndex);
  }

  void _loadActiveSubIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('active_sub_index');
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

  Color _getStatusColor() {
    if (_connected) return cyberGreen;
    if (_statusText.contains('…')) return cyberYellow;
    if (_error.isNotEmpty) return cyberPink;
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (_connected) return Icons.shield;
    if (_statusText.contains('…')) return Icons.hourglass_empty;
    if (_error.isNotEmpty) return Icons.error_outline;
    return Icons.shield_outlined;
  }

  String _getUserFriendlyError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Connection refused')) return 'Сервер недоступен. Проверьте адрес и порт.';
    if (msg.contains('Connection timed out')) return 'Превышено время ожидания. Проверьте интернет.';
    if (msg.contains('SocketException')) return 'Проблема с сетью. Попробуйте позже.';
    if (msg.contains('format')) return 'Некорректная ссылка подписки.';
    if (msg.contains('Unsupported scheme')) return 'Неподдерживаемый протокол. Используйте VLESS.';
    return 'Ошибка: $msg';
  }

  List<V2RayURL> _parseInput(String body, {required bool isSingleLink}) {
    if (isSingleLink) {
      try {
        final url = FlutterV2ray.parseFromURL(body);
        if (!body.toLowerCase().startsWith('vless://')) {
          return [];
        }
        return [url];
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
      if (!t.toLowerCase().startsWith('vless://')) continue;
      try {
        final u = FlutterV2ray.parseFromURL(t);
        urls.add(u);
      } catch (_) {}
    }
    return urls;
  }

  String _optimizeConfig(String config) {
    try {
      final Map<String, dynamic> configMap = json.decode(config);
      
      if (configMap['outbounds'] != null) {
        for (var outbound in configMap['outbounds']) {
          if (outbound['mux'] != null) {
            outbound['mux'] = {
              'enabled': false,
              'concurrency': -1
            };
          }
        }
      }

      configMap['dns'] = {
        'hosts': {},
        'servers': [
          'https://dns.google/dns-query',
          'https://cloudflare-dns.com/dns-query'
        ],
        'tag': 'dns'
      };

      if (configMap['outbounds'] != null) {
        for (var outbound in configMap['outbounds']) {
          if (outbound['streamSettings'] != null) {
            outbound['streamSettings']['sockopt'] = {
              'tcpNoDelay': true,
              'mark': 255
            };
          }
        }
      }

      return json.encode(configMap);
    } catch (e) {
      return config;
    }
  }

  Future<void> _connect() async {
    setState(() {
      _error = '';
      _testing = false;
      _isConnecting = true;
    });

    if (!_isInitialized) {
      setState(() {
        _error = 'Движок не инициализирован';
        _isConnecting = false;
      });
      return;
    }

    final subUrl = _subController.text.trim();
    if (subUrl.isEmpty || subUrl == 'https://') {
      setState(() {
        _error = 'Введите ссылку подписки или VLESS-ссылку';
        _isConnecting = false;
      });
      return;
    }

    if (!subUrl.startsWith('http') && !subUrl.startsWith('vless://')) {
      setState(() {
        _error = 'Поддерживаются только VLESS-ссылки (vless://) или подписки (https://)';
        _isConnecting = false;
      });
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
      final lower = subUrl.toLowerCase();
      String body;
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        final response = await http
            .get(Uri.parse(subUrl))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw Exception('Ошибка загрузки подписки: ${response.statusCode}');
        }
        body = response.body;
      } else {
        body = subUrl;
      }

      final bool isSingleLink = lower.startsWith('vless://');
      final List<V2RayURL> parsed = _parseInput(body, isSingleLink: isSingleLink);
      if (parsed.isEmpty) {
        setState(() {
          _error = 'Подписка не содержит серверов VLESS или ссылка недействительна.';
          _testing = false;
          _isConnecting = false;
        });
        return;
      }

      final futures = parsed.map((p) async {
        final cfg = p.getFullConfiguration();
        int ms = -1;
        try {
          ms = await _vless.getServerDelay(config: cfg);
        } catch (_) {}
        return ServerRow(p.remark, cfg, ms);
      }).toList();
      final rows = await Future.wait(futures);
      rows.sort((a, b) => a.delayMs.compareTo(b.delayMs));

      setState(() {
        _servers = rows;
        _testing = false;
        if (_activeSubIndex >= 0 && _activeSubIndex < _subscriptions.length) {
          _subscriptions[_activeSubIndex] = SubscriptionItem(
            name: _subscriptions[_activeSubIndex].name,
            url: _subscriptions[_activeSubIndex].url,
            servers: rows,
          );
        }
      });

      final best = rows.firstWhere(
        (r) => r.config.isNotEmpty,
        orElse: () => rows.first,
      );

      final optimizedConfig = _optimizeConfig(best.config);

      List<String>? blockedAppsList;
      if (_selectedPackages.isNotEmpty) {
        final allPackageNames = _allApps.map((app) => app.packageName).toList();
        blockedAppsList = allPackageNames
            .where((pkg) => !_selectedPackages.contains(pkg))
            .toList();
      }

      final granted = await _vless.requestPermission();
      if (!granted) {
        setState(() {
          _error = 'Нет прав на VPN (отклонено)';
          _isConnecting = false;
        });
        return;
      }

      await _vless.startV2Ray(
        remark: best.remark.isEmpty ? 'Veil' : best.remark,
        config: optimizedConfig,
        blockedApps: blockedAppsList,
      );

      await Future.delayed(const Duration(milliseconds: 1500));

    } catch (e) {
      setState(() {
        _error = _getUserFriendlyError(e);
        _testing = false;
      });
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    try {
      await _vless.stopV2Ray();
    } catch (e) {
      setState(() => _error = _getUserFriendlyError(e));
    }
  }

  Future<void> _selectServer(ServerRow server) async {
    if (_connected) await _disconnect();
    try {
      setState(() => _isConnecting = true);
      final granted = await _vless.requestPermission();
      if (!granted) {
        setState(() {
          _error = 'Нет прав на VPN (отклонено)';
          _isConnecting = false;
        });
        return;
      }
      
      final optimizedConfig = _optimizeConfig(server.config);
      
      await _vless.startV2Ray(
        remark: server.remark.isEmpty ? 'Veil' : server.remark,
        config: optimizedConfig,
        blockedApps: _selectedPackages.isNotEmpty
            ? _allApps.map((app) => app.packageName).where((pkg) => !_selectedPackages.contains(pkg)).toList()
            : null,
      );
    } catch (e) {
      setState(() => _error = _getUserFriendlyError(e));
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _openQrScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _subController.text = result;
        _error = '';
      });
      _connect();
    }
  }

  void _openAppSelection() async {
    if (!_appsLoaded) {
      await _loadAppsIfNeeded();
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppSelectionScreen(
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
      backgroundColor: cyberDark,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Подписки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _subscriptions.length,
                    itemBuilder: (context, i) {
                      final s = _subscriptions[i];
                      return ListTile(
                        leading: const Icon(Icons.link, color: cyberPurple),
                        title: Text(s.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(s.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (i == _activeSubIndex)
                              const Icon(Icons.check, color: cyberGreen),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: cyberPink),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: cyberDark,
                                    title: const Text('Удалить подписку?', style: TextStyle(color: Colors.white)),
                                    content: Text('Подписка "${s.name}" будет удалена.', style: const TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Отмена'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Удалить', style: TextStyle(color: cyberPink)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  setStateSheet(() {});
                                  setState(() {
                                    _subscriptions.removeAt(i);
                                    if (_activeSubIndex >= _subscriptions.length) {
                                      _activeSubIndex = _subscriptions.length - 1;
                                    }
                                    if (_activeSubIndex >= 0 && _activeSubIndex < _subscriptions.length) {
                                      _subController.text = _subscriptions[_activeSubIndex].url;
                                    } else {
                                      _subController.clear();
                                    }
                                  });
                                  _saveSubscriptions();
                                  _saveActiveSubIndex();
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _activeSubIndex = i;
                            _subController.text = s.url;
                          });
                          _saveActiveSubIndex();
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                  const Divider(color: Colors.white24),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddSubscriptionDialog();
                    },
                    icon: const Icon(Icons.add, color: cyberPurple),
                    label: const Text('Добавить', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddSubscriptionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cyberDark,
          title: const Text('Новая подписка', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'URL подписки',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final url = controller.text.trim();
                if (url.isNotEmpty) {
                  setState(() {
                    _subscriptions.add(
                      SubscriptionItem(name: 'Подписка ${_subscriptions.length + 1}', url: url),
                    );
                    _activeSubIndex = _subscriptions.length - 1;
                    _subController.text = url;
                  });
                  _saveSubscriptions();
                  _saveActiveSubIndex();
                  Navigator.pop(context);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  void _showSettings() async {
    final prefs = await SharedPreferences.getInstance();
    bool autoConnect = prefs.getBool('auto_connect') ?? false;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cyberDark,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Настройки Veil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Автоподключение при запуске', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Автоматически подключаться к активной подписке', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    value: autoConnect,
                    activeThumbColor: cyberPurple,
                    onChanged: (v) async {
                      setStateSheet(() => autoConnect = v);
                      final p = await SharedPreferences.getInstance();
                      await p.setBool('auto_connect', v);
                    },
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: cyberPurple),
                    title: const Text('О приложении', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      showAboutDialog(
                        context: context,
                        applicationName: 'Veil',
                        applicationVersion: '1.0.0',
                        applicationIcon: const Icon(Icons.visibility, color: cyberPurple, size: 48),
                        children: const [
                          Text('Клиент приватности на базе flutter_v2ray (MIT).'),
                          SizedBox(height: 8),
                          Text('Поддерживаются только VLESS-подключения.'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      setState(() {
        _subController.text = clipboardData!.text!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.visibility, color: cyberPurple),
            SizedBox(width: 8),
            Text('Veil VPN', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: cyberCyan),
            onPressed: _openQrScanner,
            tooltip: 'Сканировать QR-код',
          ),
          IconButton(
            icon: const Icon(Icons.apps, color: cyberCyan),
            onPressed: _openAppSelection,
            tooltip: 'Выбрать приложения для VPN',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: cyberCyan),
            onPressed: _showSettings,
          ),
          if (_subscriptions.isNotEmpty)
            Tooltip(
              message: 'Подписки (${_subscriptions.length})',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showManageSubscriptions,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.list_alt, color: cyberCyan, size: 24),
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: BoxDecoration(
                            color: cyberPurple,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_subscriptions.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add, color: cyberCyan),
            onPressed: _showAddSubscriptionDialog,
            tooltip: 'Добавить подписку',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cyberBlack, cyberDark, cyberBlack],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Статус с неоновым свечением
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final double scale = _connected ? (1.0 + (_pulseController.value * 0.02)) : 1.0;
                  final Color glowColor = _getStatusColor();
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cyberDark,
                            _connected ? cyberGreen.withOpacity(0.2) : cyberPurple.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: glowColor.withOpacity(0.6),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _getStatusIcon(),
                            size: 48,
                            color: glowColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: glowColor,
                            ),
                          ),
                          if (_selectedPackages.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'VPN только для ${_selectedPackages.length} приложений',
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ),
                          if (_error.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _error,
                                style: const TextStyle(color: cyberPink, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Поле ввода подписки с неоновой рамкой
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cyberDark.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cyberPurple.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: cyberPurple.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link, color: cyberCyan, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Ссылка подписки',
                          style: TextStyle(color: cyberCyan, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _subController.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: cyberCyan),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _subController.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Скопировано')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, color: cyberPink),
                          onPressed: () => _subController.clear(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openQrScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('QR-код'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cyberCyan,
                              side: const BorderSide(color: cyberCyan),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.paste),
                            label: const Text('Из буфера'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cyberCyan,
                              side: const BorderSide(color: cyberCyan),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Большая неоновая кнопка подключения
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (_connected) {
                      _disconnect();
                    } else if (!_isConnecting && !_testing && _isInitialized) {
                      _connect();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final double scale = _connected ? (1.0 + (_pulseController.value * 0.05)) : 1.0;
                      final Color glowColor = _connected ? cyberGreen : cyberPurple;
                      
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _connected 
                                  ? [cyberGreen, cyberCyan]
                                  : [cyberPurple, cyberPink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withOpacity(0.6),
                                blurRadius: 30,
                                spreadRadius: 8,
                              ),
                              BoxShadow(
                                color: glowColor.withOpacity(0.3),
                                blurRadius: 50,
                                spreadRadius: 15,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _connected ? Icons.power_settings_new : Icons.play_arrow,
                                size: 56,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isConnecting ? '...' : (_connected ? 'ОТКЛЮЧИТЬ' : 'ПОДКЛЮЧИТЬ'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              if (_testing) 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(cyberPurple),
                    backgroundColor: cyberDark,
                  ),
                ),
                
              const SizedBox(height: 24),

              // Заголовок списка серверов
              Row(
                children: [
                  const Text('Доступные серверы', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cyberCyan)),
                  const Spacer(),
                  if (_servers.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cyberPurple.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cyberPurple.withOpacity(0.5)),
                      ),
                      child: Text(
                        '${_servers.length}',
                        style: const TextStyle(color: cyberPurple, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Список серверов с неоновыми эффектами
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _servers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.dns, size: 48, color: cyberPurple.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'Нет серверов. Введите ссылку и нажмите "Подключить"',
                                style: TextStyle(color: Colors.white54),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          key: ValueKey(_servers.length),
                          itemCount: _servers.length,
                          itemBuilder: (context, i) {
                            return _buildServerCard(_servers[i], i);
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerCard(ServerRow s, int index) {
    final int ms = s.delayMs;
    Color pingColor;
    String pingText;
    
    if (ms < 0) {
      pingColor = Colors.grey;
      pingText = 'нет ответа';
    } else if (ms < 100) {
      pingColor = cyberGreen;
      pingText = '$ms мс';
    } else if (ms < 250) {
      pingColor = cyberYellow;
      pingText = '$ms мс';
    } else {
      pingColor = cyberPink;
      pingText = '$ms мс';
    }

    String flag = '🌍';
    final remarkLower = s.remark.toLowerCase();
    if (remarkLower.contains('us') || remarkLower.contains('usa')) flag = '🇺';
    else if (remarkLower.contains('de') || remarkLower.contains('germany')) flag = '🇩🇪';
    else if (remarkLower.contains('nl') || remarkLower.contains('netherlands')) flag = '🇳🇱';
    else if (remarkLower.contains('ru') || remarkLower.contains('russia')) flag = '🇷🇺';
    else if (remarkLower.contains('jp') || remarkLower.contains('japan')) flag = '🇯🇵';
    else if (remarkLower.contains('gb') || remarkLower.contains('uk')) flag = '🇬🇧';

    final isBest = index == 0 && ms >= 0;

    return GestureDetector(
      onTap: ms >= 0 ? () => _selectServer(s) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cyberDark.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBest ? cyberPurple : cyberPurple.withOpacity(0.3),
            width: isBest ? 2 : 1,
          ),
          boxShadow: isBest ? [
            BoxShadow(
              color: cyberPurple.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.remark.isEmpty ? 'Сервер ${index + 1}' : s.remark,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isBest) ...[
                        const Icon(Icons.bolt, color: cyberGreen, size: 14),
                        const SizedBox(width: 4),
                        const Text('Лучший', style: TextStyle(color: cyberGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        pingText,
                        style: TextStyle(color: pingColor, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (ms >= 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pingColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pingColor.withOpacity(0.5)),
                ),
                child: Text(
                  pingText,
                  style: TextStyle(
                    color: pingColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
    return widget.apps
        .where((app) => app.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cyberBlack,
      appBar: AppBar(
        backgroundColor: cyberDark,
        title: const Text('Выбор приложений для VPN'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSave(_tempSelected);
              Navigator.pop(context);
            },
            child: const Text('Сохранить', style: TextStyle(color: cyberCyan)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск приложений...',
                prefixIcon: const Icon(Icons.search, color: cyberCyan),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: cyberPurple),
                ),
                filled: true,
                fillColor: cyberDark,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: _filteredApps.length,
        itemBuilder: (context, index) {
          final app = _filteredApps[index];
          return CheckboxListTile(
            title: Text(app.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(app.packageName, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            value: _tempSelected.contains(app.packageName),
            activeColor: cyberPurple,
            checkColor: Colors.white,
            onChanged: (bool? selected) {
              setState(() {
                if (selected == true) {
                  _tempSelected.add(app.packageName);
                } else {
                  _tempSelected.remove(app.packageName);
                }
              });
            },
          );
        },
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: cyberCyan,
        title: const Text('Сканировать QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Фонарик',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Сменить камеру',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Камера недоступна:\n${error.errorDetails?.message ?? error.errorCode.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: cyberPurple, width: 3),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cyberPurple.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cyberCyan.withOpacity(0.5)),
                ),
                child: const Text(
                  'Наведите на QR-код с VPN-ссылкой',
                  style: TextStyle(color: cyberCyan, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}