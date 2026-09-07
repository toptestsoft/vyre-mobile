import 'package:flutter/material.dart';
import 'package:vyre/utils/constants.dart';
import 'package:vyre/widgets/glass_card.dart';

class BentoStatus extends StatelessWidget {
  final bool connected;
  final String statusText;
  final int selectedCount;
  final int serverCount;
  final String? activeSub;
  final String? trafficLabel;

  const BentoStatus({
    super.key,
    required this.connected,
    required this.statusText,
    this.selectedCount = 0,
    this.serverCount = 0,
    this.activeSub,
    this.trafficLabel,
  });

  @override
  Widget build(BuildContext context) {
    final statusGlow = connected ? kGlowCyan : kGlowPurple;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  statusGlow.withOpacity(0.8),
                  statusGlow.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GradientText(
            statusText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            colors: connected
                ? [kAccentCyan, kAccentMagenta]
                : [kAccentPurple, kAccentMagenta],
          ),
          if (trafficLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              trafficLabel!,
              style: TextStyle(color: kTextMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
