# VYRE Release Process

## Versioning

- Set `version: X.Y.Z+N` in `pubspec.yaml`.
- `versionName` = `X.Y.Z`
- `versionCode` = `N` from `pubspec.yaml`, passed through unchanged to `android/app/build.gradle.kts`.
- Do not invent an extra offset; the actual build formula is direct passthrough.

## Changelog

- Add a `[X.Y.Z+N]` section to `CHANGELOG.md` with the date.
- Include only verified `Fixed` and `Changed` items.
- Do not add unverified promises or future work.

## Pre-release checks

- Run `flutter analyze` — must report `No issues found!`.
- Run `flutter test` — all tests must pass.
- Do not proceed if either check fails.

## Commit and tag

- Commit release changes with message `chore: release X.Y.Z+N`.
- Create and push tag `vX.Y.Z+N`.

## CI build and GitHub Release

- GitHub Actions triggers on the pushed tag.
- CI builds a **universal** `app-release.apk` using the production keystore from repository secrets.
- CI creates a GitHub Release with:
  - `app-release.apk`
  - `screenshots/home.png`
  - `screenshots/icon.png`
  - `screenshots/servers.png`
  - `screenshots/subs.png`
  - `screenshots/qr.png`

## Verification

- Download `app-release.apk` from the created GitHub Release.
- Verify the APK signature with `apksigner`; the certificate SHA-256 must match the project production fingerprint.
- Install the CI artifact on a test device and perform a smoke test: START, Connected state, IP check, STOP.
- Publish the forum link only after signature verification and smoke test pass.

## Artifact format

- The only published artifact is the **universal** `app-release.apk`.
- `--split-per-abi` is not used in the release process.
