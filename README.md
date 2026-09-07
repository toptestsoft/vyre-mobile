# VYRE VPN

> Flutter-приложение для безопасного VPN от VYRE.

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue)
[![CI](https://github.com/toptestsoft/vyre-mobile/actions/workflows/flutter-ci.yml/badge.svg?branch=main)](https://github.com/toptestsoft/vyre-mobile/actions/workflows/flutter-ci.yml)
![License](https://img.shields.io/badge/License-MIT-green)
![Flutter](https://img.shields.io/badge/Flutter-≥3.29-blue)
![Dart](https://img.shields.io/badge/Dart-≥3.7-blue)
[![GitHub Release](https://img.shields.io/github/v/release/toptestsoft/vyre-mobile?color=green&label=Release)](https://github.com/toptestsoft/vyre-mobile/releases/latest)

<!-- TODO: Add CI badge after setting up GitHub Actions -->
<!-- ![Build](https://img.shields.io/github/actions/workflow/status/toptestsoft/vyre-mobile/flutter-ci.yml?branch=main) -->

## 📱 Screenshots

<p float="left">
  <img src="screenshots/home.png" width="240" alt="Главный экран" />
</p>

## ✨ Features

- **Быстрое подключение** — один тап для подключения к лучшему серверу
- **Несколько локаций** — выбор из 3+ серверов с задержкой и пингом
- **Двойная оплата** — Telegram Stars и USDT (CryptoBot)
- **Secure Storage** — подписки хранятся зашифрованно на устройстве
- **Split-tunneling** — выборочный роутинг трафика *(в разработке)*
- **Автообновление** — проверка обновлений через GitHub Releases
- **Без логов** — политика конфиденциальности: никаких данных не собирается

## 🚀 Roadmap

- [x] Android (arm64, armeabi, x86_64)
- [ ] iOS
- [ ] Локализация (i18n: EN, RU, ZH)
- [ ] Sentry crash reporting
- [ ] Split-tunneling

## 🔒 Privacy

См. [PRIVACY.md](PRIVACY.md) — никакие данные не собираются.

## 📦 Download

📥 [Скачать APK v1.1.0](https://github.com/toptestsoft/vyre-mobile/releases/tag/v1.1.0)

Требуется Android 6.0+ (API 23).

## 🛠️ Build

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

## 📄 License

MIT — см. [LICENSE](LICENSE).
