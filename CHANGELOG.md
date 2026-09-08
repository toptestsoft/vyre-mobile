# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0+2] - 2025-09-08

### Fixed
- `Target of URI doesn't exist` for `url_launcher`, `device_info_plus`, `flutter_secure_storage` — forced artifact download in CI
- `errorBuilder` signature in QR scanner — removed deprecated child parameter
- `VpnService` constructor — switched to `this.onStateChanged`

### Changed
- Replaced `package:vyre/...` imports with relative imports in `update_service.dart`, `bento_status.dart`, `glass_card.dart`, `servers_sheet.dart`, `subscriptions_sheet.dart`
- Updated pubspec.yaml version: `1.1.0+2` (was `1.0.0+1`)
- `flutter analyze` now fails CI on any issue (removed `|| true` bypass)