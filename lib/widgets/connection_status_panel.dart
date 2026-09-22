import 'package:flutter/material.dart';
import '../models/vpn_state.dart';
import '../utils/constants.dart';
import 'glass_card.dart';

class ConnectionStatusPanel extends StatelessWidget {
  final VpnState vpnState;
  final String? notice;
  final String? error;
  final int serversCount;
  final int? bestDelayMs;
  final String? connectedServer;
  final String? connectedProtocol;
  final bool hasSubscription;

  const ConnectionStatusPanel({
    super.key,
    required this.vpnState,
    this.notice,
    this.error,
    required this.serversCount,
    this.bestDelayMs,
    this.connectedServer,
    this.connectedProtocol,
    required this.hasSubscription,
  });

  @override
  Widget build(BuildContext context) {
    final header = _headerText();
    final headerColor = _headerColor();
    final body = _bodyText();

    return GlassCard(
      padding: const EdgeInsets.all(kSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: headerColor,
            ),
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                color: kTextMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _headerText() {
    if (_hasError) return '✕ $error';
    if (_hasNotice) return 'ℹ $notice';

    switch (vpnState) {
      case VpnState.connected:
        return '● Подключено';
      case VpnState.testing:
        return '◌ Поиск лучшего сервера';
      case VpnState.connecting:
        return '◌ Подключение...';
      case VpnState.disconnecting:
        return '◌ Отключение...';
      case VpnState.initializing:
        return '◌ Инициализация...';
      case VpnState.disconnected:
        if (serversCount > 0) return '✓ Подписка загружена';
        if (hasSubscription) return '○ Ссылка добавлена';
        return '○ Готово к подключению';
      case VpnState.error:
        return '✕ Не удалось подключиться';
    }
  }

  Color _headerColor() {
    if (_hasError) return kStatusErr;
    if (_hasNotice) return kStatusNeutral;

    switch (vpnState) {
      case VpnState.connected:
        return kStatusOk;
      case VpnState.testing:
      case VpnState.connecting:
      case VpnState.disconnecting:
        return kStatusAccent;
      case VpnState.initializing:
        return kStatusNeutral;
      case VpnState.disconnected:
        return kStatusNeutral;
      case VpnState.error:
        return kStatusErr;
    }
  }

  String? _bodyText() {
    if (_hasError) {
      if (serversCount > 0) return 'Проверьте подписку и сервер';
      if (hasSubscription) return 'Проверьте ссылку подписки';
      return 'Добавьте подписку';
    }

    switch (vpnState) {
      case VpnState.connected:
        final parts = <String>[];
        if (connectedProtocol != null && connectedProtocol!.isNotEmpty) {
          parts.add(connectedProtocol!);
        }
        if (connectedServer != null && connectedServer!.isNotEmpty) {
          parts.add(connectedServer!);
        }
        if (bestDelayMs != null) parts.add('$bestDelayMs мс');
        if (parts.isEmpty) return null;
        return parts.join(' · ');
      case VpnState.testing:
        return 'Проверяем серверы...';
      case VpnState.disconnected:
        if (serversCount > 0 && bestDelayMs != null) {
          return '$serversCount серверов · лучший $bestDelayMs мс';
        }
        if (hasSubscription) return 'Нажмите START';
        return 'Добавьте подписку';
      default:
        return null;
    }
  }

  bool get _hasError => error != null && error!.isNotEmpty;
  bool get _hasNotice => notice != null && notice!.isNotEmpty;
}
