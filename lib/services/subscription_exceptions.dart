class SubscriptionException implements Exception {
  final String message;
  const SubscriptionException(this.message);
  @override
  String toString() => message;
}

class SubscriptionTimeoutException extends SubscriptionException {
  const SubscriptionTimeoutException([String? message])
      : super(message ?? 'Таймаут при загрузке подписки');
}

class SubscriptionSizeLimitException extends SubscriptionException {
  const SubscriptionSizeLimitException([String? message])
      : super(message ?? 'Превышен лимит размера ответа');
}

class SubscriptionRedirectException extends SubscriptionException {
  const SubscriptionRedirectException([String? message])
      : super(message ?? 'Ошибка редиректа');
}
