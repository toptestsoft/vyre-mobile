import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'glass_card.dart';

class SubscriptionCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onPaste;
  final VoidCallback onScanQr;
  final bool isTesting;
  final ValueChanged<String>? onChanged;

  const SubscriptionCard({
    super.key,
    required this.controller,
    required this.onPaste,
    required this.onScanQr,
    this.isTesting = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(kSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 18, color: kAccentCyan),
              const SizedBox(width: 8),
              const Text('Подключение', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
            ],
          ),
          if (controller.text.isEmpty) ...[
            const SizedBox(height: kSpace2),
            const Text(
              'Вставьте ссылку на подписку\nили используйте QR-код сверху',
              style: TextStyle(color: kTextMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: kSpace2),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(color: kTextPrimary, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  hintText: 'Вставьте URL подписки',
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
                        onPressed: onPaste,
                        tooltip: 'Вставить',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isTesting) ...[
            const SizedBox(height: kSpace2),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
