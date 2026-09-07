import 'package:flutter/material.dart';
import 'package:vyre/utils/constants.dart';
import 'package:vyre/widgets/glass_card.dart';
import 'package:vyre/models/subscription.dart';

// ─── SubscriptionsSheet ───
class SubscriptionsSheet extends StatefulWidget {
  final List<SubscriptionItem> subscriptions;
  final int activeIndex;
  final TextEditingController controller;
  final Function(int) onSelect;
  final Function(String) onAdd;
  final Function(int) onDelete;

  const SubscriptionsSheet({
    super.key,
    required this.subscriptions,
    required this.activeIndex,
    required this.controller,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<SubscriptionsSheet> createState() => _SubscriptionsSheetState();
}

class _SubscriptionsSheetState extends State<SubscriptionsSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
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
          const Text('Подписки',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.subscriptions.length,
              itemBuilder: (context, i) {
                final s = widget.subscriptions[i];
                final isActive = i == widget.activeIndex;
                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(s.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      s.url,
                      style: TextStyle(color: kTextSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive)
                          const Icon(Icons.check_circle, color: kSuccess, size: 22),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx2) => AlertDialog(
                                backgroundColor: const Color(0xFF0a0a1a),
                                title: const Text('Удалить подписку?',
                                    style: TextStyle(color: Colors.white)),
                                content: const Text('Это действие необратимо.',
                                    style: TextStyle(color: kTextMuted)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx2),
                                    child: const Text('Отмена', style: TextStyle(color: kTextMuted))
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx2);
                                      widget.onDelete(i);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Удалить', style: TextStyle(color: kDanger))
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Icon(Icons.delete_outline, color: kDanger, size: 18),
                        ),
                      ],
                    ),
                    onTap: () => widget.onSelect(i),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                final url = await _promptForSubscription(context);
                if (url != null && url.isNotEmpty) {
                  widget.onAdd(url);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentCyan.withOpacity(0.15),
                foregroundColor: kAccentCyan,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Добавить подписку'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Future<String?> _promptForSubscription(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0a0a1a),
        title: const Text('Новая подписка', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'https://example.com/subscription.txt',
            hintStyle: TextStyle(color: kTextMuted),
          ),
          style: TextStyle(color: kTextPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Добавить')),
        ],
      ),
    );
  }
}
