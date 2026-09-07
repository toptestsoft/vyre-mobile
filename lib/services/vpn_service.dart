import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../models/vpn_state.dart';

/// Единственная точка контакта с движком VPN.
class VpnService {
  VpnService({required this.onStateChanged});

  final void Function(VpnState state, String rawState) onStateChanged;
  late final FlutterV2ray _v2ray;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        onStateChanged(_mapState(status.state), status.state);
      },
    );
    await _v2ray.initializeV2Ray();
    _initialized = true;
  }

  Future<bool> requestPermission() => _v2ray.requestPermission();

  Future<void> connect({
    required String remark,
    required String config,
    List<String>? blockedApps,
  }) =>
      _v2ray.startV2Ray(remark: remark, config: config, blockedApps: blockedApps);

  Future<void> disconnect() => _v2ray.stopV2Ray();

  Future<int> pingServer(String config) async {
    try {
      return await _v2ray.getServerDelay(config: config);
    } catch (_) {
      return -1;
    }
  }

  VpnState _mapState(String raw) => switch (raw) {
        'CONNECTED' => VpnState.connected,
        'CONNECTING' => VpnState.connecting,
        'DISCONNECTING' => VpnState.disconnecting,
        'DISCONNECTED' => VpnState.disconnected,
        _ => VpnState.disconnected, // CONNECTED_NOT и пр. не ломают состояние
      };
}
