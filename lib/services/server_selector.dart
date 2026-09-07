import '../models/subscription.dart'; // ServerRow
import '../models/vpn_state.dart';    // ServerStatus

/// Чистая, тестируемая логика выбора сервера. Никакого UI и VPN.
class ServerSelector {
  const ServerSelector();

  /// Сортировка: доступные по возрастанию задержки, затем недоступные.
  /// -1 (ошибка проверки) НИКОГДА не может стать «лучшим».
  List<ServerRow> sort(List<ServerRow> rows) {
    final ok = rows.where((r) => r.delayMs >= 0).toList()
      ..sort((a, b) => a.delayMs.compareTo(b.delayMs));
    final bad = rows.where((r) => r.delayMs < 0).toList();
    return [...ok, ...bad];
  }

  /// Лучший = первый из доступных. Если доступных нет — null
  /// (решение «подключаться вслепую или нет» принимает вызывающий код).
  ServerRow? selectBest(List<ServerRow> sorted) {
    for (final r in sorted) {
      if (r.delayMs >= 0 && r.config.isNotEmpty) return r;
    }
    return null;
  }

  /// Fallback для продукта: если ни один сервер не ответил,
  /// берём первый с непустым конфигом (подключение «на авось»).
  ServerRow? fallbackAny(List<ServerRow> rows) {
    for (final r in rows) {
      if (r.config.isNotEmpty) return r;
    }
    return rows.isEmpty ? null : rows.first;
  }
}