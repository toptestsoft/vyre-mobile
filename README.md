# VYRE VPN

> Flutter-приложение для безопасного VPN от VYRE.

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)

## О приложении

VYRE VPN — мобильное приложение для подключения к VPN-серверам по подписке. Поддерживает подписки через Telegram Stars и USDT (TRC20).

## Скачать

Готовые APK для Android доступны в [Releases](https://github.com/toptestsoft/vyre-mobile/releases).

| Архитектура | Файл | Размер |
|-------------|------|--------|
| arm64-v8a | `vyre-arm64-v8a-release.apk` | ~28 MB |
| armeabi-v7a | `vyre-armeabi-v7a-release.apk` | ~28 MB |
| x86_64 | `vyre-x86_64-release.apk` | ~30 MB |

## Установка

1. Скачайте APK нужной архитектуры из [Releases](https://github.com/toptestsoft/vyre-mobile/releases/tag/v1.1.0)
2. Разрешите установку из неизвестных источников
3. Установите и откройте приложение

## Для разработчиков

### Требования

- Flutter SDK 3.x
- Android SDK

### Сборка

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

APK появятся в `build/app/outputs/flutter-apk/`.

### Структура проекта

```
lib/
  main.dart              # Точка входа, UI
  models/                # Модели данных
    vpn_state.dart       # VpnState enum
    subscription.dart     # SubscriptionItem, ServerRow
  services/              # Бизнес-логика
    vpn_service.dart     # FlutterV2ray обёртка
    subscription_service.dart  # Загрузка/парсинг подписок
    subscription_repository.dart # Персистенция подписок
    subscription_cache.dart    # Офлайн-кэш
    server_selector.dart # Выбор сервера по пингу
    update_service.dart  # Проверка обновлений
  utils/
    constants.dart       # Цвета, строки, константы
    helpers.dart         # Утилиты
  widgets/               # Переиспользуемые виджеты
    glass_card.dart
    bento_status.dart
    servers_sheet.dart
    subscriptions_sheet.dart
```

### Тесты

```bash
flutter test
```

## Авто-обновление

Приложение проверяет обновления через GitHub Releases. Кнопка **"Проверить обновления"** доступна в разделе *VYRE*.

## Бот поддержки

[@VYREPayBot](https://t.me/VYREPayBot) — бот для покупки подписок через Telegram Stars или USDT.

## Лицензия

MIT
