# 🛡️ VYRE Secure Access

**VYRE Secure Access** — это современный клиент для защищённого интернет-соединения на базе протокола VLESS с поддержкой Reality. Приложение разработано на Flutter и предоставляет полный контроль над вашим интернет-трафиком.

## ✨ Особенности

- 🔒 **Протокол VLESS + Reality** — высокая производительность и скрытность соединения.
- 📱 **Выбор приложений** — можно настроить, какие приложения будут использовать защищённый канал, а какие — нет (Split Tunneling).
- 📷 **QR-сканер** — быстрое подключение по отсканированной ссылке.
- 📋 **Управление подписками** — добавление, удаление и переключение между несколькими источниками доступа.
- 🔄 **Автоматические обновления** — приложение само проверяет новые версии через GitHub Releases и предлагает установить их.
- 🎨 **Стеклянный дизайн (Glassmorphism)** — современный и приятный интерфейс с тёмной темой.
- 🆓 **Бесплатно и без рекламы** — проект с открытым исходным кодом.

---

# 🛡️ VYRE Secure Access

**VYRE Secure Access** — A modern secure internet connection client based on the VLESS protocol with Reality support. Built with Flutter, it gives you full control over your internet traffic.

## ✨ Features

- 🔒 **VLESS + Reality protocol** — High performance and stealth of the connection.
- 📱 **App selection** — Configure which apps use the secure channel and which don't (Split Tunneling).
- 📷 **QR Scanner** — Fast connection via scanned link.
- 📋 **Subscription management** — Add, delete, and switch between multiple sources.
- 🔄 **Auto-updates** — The app checks for new versions via GitHub Releases and prompts installation.
- 🎨 **Glassmorphism design** — Modern dark-themed interface.
- 🆓 **Free and ad-free** — Open source project.

## 📲 Installation

### 📦 Download APK

1. Go to the [Releases](https://github.com/toptestsoft/vyre-mobile/releases) page.
2. Download the latest `app-release.apk`.
3. Allow installation from unknown sources (in device security settings).
4. Open the APK and install.

### 🛠️ Build from source

```bash
git clone https://github.com/toptestsoft/vyre-mobile.git
cd vyre-mobile
flutter pub get
flutter build apk --release
```

## 📖 Usage

### Connecting to a secure channel
1. Open the app.
2. Paste your VLESS link (starts with `vless://`) or subscription URL in the "Subscription Link" field.
3. Press the central START button.
4. Allow VPN connection permission on first launch.

### App selection (Split Tunneling)
1. Tap the "Apps" icon in the top-right.
2. Select apps to route through the secure channel.
3. Tap "Save".

### Subscription management
1. Tap the "Subscriptions" icon (list) in the top-right.
2. Add, delete, or switch between subscriptions.

### QR Scanner
1. Tap the "QR Scanner" icon in the top-right.
2. Scan a QR code with a VLESS link.

## 🔄 App Updates
The app checks for new versions on startup. If available:
1. A dialog with changelog appears.
2. Tap "Update".
3. APK downloads and opens system install prompt.

## 🛡️ Security & Privacy
- All traffic is encrypted using modern cryptographic algorithms.
- No personal data is collected or stored.
- Connection logs are stored locally only.

## 🤝 Contributing
Contributions are welcome! Open an issue or submit a PR.

## 📜 License
Distributed under the MIT License. See `LICENSE` for details.
