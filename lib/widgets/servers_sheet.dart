import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/subscription.dart';

class ServersSheet extends StatelessWidget {
  final List<ServerRow> servers;

  const ServersSheet({super.key, required this.servers});

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
                color: kSurface.withValues(alpha: 0.95),
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
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Серверы',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
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
                        final isBest = (i == 0 && s.delayMs >= 0);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isBest
                                ? kAccentCyan.withValues(alpha: 0.10)
                                : kGlass,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isBest
                                  ? kAccentCyan.withValues(alpha: 0.4)
                                  : kGlassBorder,
                              width: isBest ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                s.delayMs >= 0 ? Icons.wifi : Icons.wifi_off,
                                color: s.delayMs >= 0 ? kSuccess : kTextMuted,
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.remark.isEmpty ? 'Сервер ${i + 1}' : s.remark,
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.delayMs >= 0 ? '${s.delayMs} мс' : 'Недоступен',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: s.delayMs >= 0 ? kTextSecondary : kTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isBest)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kSuccess.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Лучший',
                                    style: TextStyle(fontSize: 11, color: kSuccess, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
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
