import 'package:flutter/material.dart';
import '../models/vpn_state.dart';
import '../utils/constants.dart';

class StartButton extends StatefulWidget {
  final VpnState vpnState;
  final bool isConnected;
  final bool canStart;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;

  const StartButton({
    super.key,
    required this.vpnState,
    required this.isConnected,
    required this.canStart,
    this.onStart,
    this.onStop,
    this.onCancel,
  });

  @override
  State<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<StartButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isPulsing = widget.vpnState == VpnState.testing ||
        widget.vpnState == VpnState.connecting ||
        widget.vpnState == VpnState.disconnecting ||
        widget.isConnected;
    if (isPulsing && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isPulsing && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.isConnected;
    final isPulsing = widget.vpnState == VpnState.testing ||
        widget.vpnState == VpnState.connecting ||
        widget.vpnState == VpnState.disconnecting ||
        widget.isConnected;
    final scale = isPulsing ? _pulseAnim.value : 1.0;
    final statusColor = isConnected ? kSuccess : kDanger;
    final statusGlow = isConnected ? kGlowCyan : kGlowPurple;

    VoidCallback? onTap;
    if (isConnected) {
      onTap = widget.onStop;
    } else if (widget.vpnState == VpnState.testing ||
        widget.vpnState == VpnState.connecting ||
        widget.vpnState == VpnState.disconnecting) {
      onTap = widget.onCancel;
    } else if (widget.canStart) {
      onTap = widget.onStart;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _glowAnim]),
      builder: (context, child) {
        return Semantics(
          button: true,
          label: isConnected
              ? 'Отключиться от VPN'
              : ((widget.vpnState == VpnState.testing ||
                      widget.vpnState == VpnState.connecting ||
                      widget.vpnState == VpnState.disconnecting)
                  ? 'Отменить'
                  : 'СТАРТ'),
          enabled: isConnected || widget.canStart ||
              widget.vpnState == VpnState.testing ||
              widget.vpnState == VpnState.connecting ||
              widget.vpnState == VpnState.disconnecting,
          child: GestureDetector(
            onTap: onTap,
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
                        colors: isConnected
                            ? [
                                kAccentCyan.withValues(alpha: 0.3),
                                kAccentPurple.withValues(alpha: 0.2),
                              ]
                            : [kSurfaceLight, kSurface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: isConnected ? kAccentCyan.withValues(alpha: 0.4) : kGlassBorder,
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
                            isConnected
                                ? Icons.stop_rounded
                                : ((widget.vpnState == VpnState.testing ||
                                        widget.vpnState == VpnState.connecting ||
                                        widget.vpnState == VpnState.disconnecting)
                                    ? Icons.close_rounded
                                    : Icons.play_arrow_rounded),
                            size: 56,
                            color: (widget.vpnState == VpnState.testing ||
                                    widget.vpnState == VpnState.connecting ||
                                    widget.vpnState == VpnState.disconnecting)
                                ? kDanger
                                : (isConnected ? kDanger : kTextPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isConnected
                                ? 'СТОП'
                                : ((widget.vpnState == VpnState.testing ||
                                        widget.vpnState == VpnState.connecting ||
                                        widget.vpnState == VpnState.disconnecting)
                                    ? 'ОТМЕНА'
                                    : 'СТАРТ'),
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
    );
  }
}
