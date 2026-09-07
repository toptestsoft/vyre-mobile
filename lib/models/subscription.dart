// ─── Модели данных для подписок и серверов ───
class ServerRow {
  final String remark;
  final String config;
  final int delayMs;

  // Именованные параметры (как в оригинальном коде)
  ServerRow({
    required this.remark,
    required this.config,
    this.delayMs = -1,
  });

  Map<String, dynamic> toJson() => {
        'remark': remark,
        'config': config,
        'delayMs': delayMs,
      };

  factory ServerRow.fromJson(Map<String, dynamic> json) => ServerRow(
        remark: json['remark'] as String? ?? '',
        config: json['config'] as String? ?? '',
        delayMs: json['delayMs'] as int? ?? -1,
      );
}

/// Модель подписки с сериализацией и уникальным ID
class SubscriptionItem {
  final String id;
  final String name;
  final String url;
  final List<ServerRow> servers;

  SubscriptionItem({
    String? id,
    required this.name,
    required this.url,
    this.servers = const [],
  })  : id = id ??
            // Простой уникальный ID на основе времени
            DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'servers': servers.map((s) => s.toJson()).toList(),
      };

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) => SubscriptionItem(
        id: (json['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
        servers: (json['servers'] as List<dynamic>?) == null
            ? <ServerRow>[]
            : (json['servers'] as List<dynamic>)
                .map((s) =>
                    ServerRow.fromJson(Map<String, dynamic>.from(s as Map)))
                .toList(),
      );
}
