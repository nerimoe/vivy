# Vivy

Vivy is a household Kiosk and desktop companion. The Kiosk is built with Flutter for Android and Chromium PWA. The desktop daemon is a Rust/Axum service for trusted local networks.

## Development

```sh
cd apps/vivy_kiosk
flutter test
flutter run -d chrome
```

```sh
cd services/vivy_daemon
cargo test
cargo run
```

The daemon listens on `0.0.0.0:43821` by default. Override it with `VIVY_BIND`.

Copy `services/vivy_daemon/config.example.json` to
`~/.config/vivy/daemon.json` and edit the aliases that the Kiosk may invoke.
Set `VIVY_CONFIG` to use another path. Applications and shortcuts are executed
as fixed program/argument arrays; aliases received over the network are never
interpreted as shell commands. `open_url` only accepts HTTP(S) hosts listed in
`allowed_url_hosts`.

The Web release can be served locally for development:

```sh
cd apps/vivy_kiosk
flutter build web --release
python3 -m http.server 4173 --directory build/web
```

Camera access requires HTTPS outside `localhost`. Android builds require a full
Android SDK with command-line tools, the Flutter-selected NDK, and accepted SDK
licenses.

## Android Releases

Every push runs `.github/workflows/android-release.yml`. It verifies the Flutter
project and publishes an ARM64 APK to a GitHub Release named
`<version>+<short-commit>`. The workflow compares `apps/vivy_kiosk/pubspec.yaml`
with the latest non-prerelease release: an unchanged (or older) version becomes
a pre-release, while a newer version becomes the latest formal release.

See `CHECKPOINT.md` for the active milestone and verified progress.
