import 'dart:convert';

/// Преобразует технические ошибки в понятные сообщения
String getUserFriendlyError(dynamic e) {
  final s = e.toString().toLowerCase();
  if (s.contains('timeout') || s.contains('timed out')) return 'Превышено время ожидания';
  if (s.contains('network') || s.contains('connection')) return 'Проверьте подключение к интернету';
  if (s.contains('invalid') || s.contains('parse')) return 'Некорректная ссылка или подписка';
  if (s.contains('permission')) return 'Недостаточно прав для выполнения операции';
  if (s.contains('ssl') || s.contains('tls') || s.contains('certificate')) {
    return 'Ошибка сертификата сервера';
  }
  return 'Неизвестная ошибка. Попробуйте позже.';
}

/// Декодирует base64/base64url подписку, отбрасывает BOM.
class SubscriptionDecoder {
  static String decode(String raw) {
    if (raw.isEmpty) return '';
    var text = raw.trim();
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    if (!text.contains('://') && !text.contains('{')) {
      try {
        String normalized = text.replaceAll(RegExp(r'[\s\r\n]+'), '');
        while (normalized.length % 4 != 0) normalized += '=';
        normalized = normalized.replaceAll('-', '+').replaceAll('_', '/');
        text = utf8.decode(base64Decode(normalized));
      } catch (_) {}
    }
    return text;
  }
}
