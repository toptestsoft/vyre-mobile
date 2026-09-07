/// Единая модель состояния VPN. Заменяет набор булов:
/// невозможные комбинации (_connected && _testing) теперь непредставимы.
enum VpnState {
  initializing,
  disconnected,
  testing,
  connecting,
  connected,
  disconnecting,
  error;

  bool get isConnected => this == VpnState.connected;
  bool get isBusy =>
      this == testing || this == connecting || this == disconnecting;
  bool get canStart => this == disconnected || this == error;
}

/// Статус сервера: отделяем «неизвестно/недоступен/ошибка» от задержки.
enum ServerStatus { unknown, available, unavailable }

/// Результат парсинга подписки: теперь видно, сколько конфигов отброшено.
class ParseResult {
  final List<dynamic> servers; // List<V2RayURL>
  final int invalidCount;
  const ParseResult({required this.servers, this.invalidCount = 0});

  bool get isEmpty => servers.isEmpty;
  String get summary => 'Найдено серверов: ${servers.length}'
      '${invalidCount > 0 ? ' · отброшено невалидных: $invalidCount' : ''}';
}