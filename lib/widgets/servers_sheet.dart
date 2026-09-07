import 'package:flutter/material.dart';
import 'package:vyre/utils/constants.dart';
import 'package:vyre/widgets/glass_card.dart';
import 'package:vyre/models/subscription.dart';

class ServersSheet extends StatelessWidget {
  final List<ServerRow> servers;

  const ServersSheet({super.key, required this.servers});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: kSurface.withOpacity(0.95),
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
              color: kGlassBorder,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Список серверов',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: servers.length,
              itemBuilder: (context, i) {
                final s = servers[i];
                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(s.remark, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      s.delayMs >= 0 ? '${s.delayMs} ms' : 'Неизвестно',
                      style: TextStyle(color: kTextSecondary, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
