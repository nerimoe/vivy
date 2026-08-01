# Vivy Implementation Checkpoint

Last updated: 2026-08-02 (Information rail container and type scale verified)

## Objective

Build Vivy as a long-running household Kiosk with a shared Flutter Android/Web UI, a Rust/Axum desktop daemon, local recording, LAN video streaming, reminders, alarms, Google data, and Android-only voice assistance.

## Locked Decisions

- The first screen is a single, non-scrolling clock-focused Kiosk surface.
- Recording is represented by a status light until the user opens its details.
- Theme selection uses Android ambient light first and sunrise/sunset as fallback.
- Flutter supports Android and Chromium installed PWA; the daemon uses Rust, Tokio, and Axum.
- The trusted household LAN APIs have no account or pairing authentication.
- Android uses screen pinning rather than Device Owner provisioning.
- macOS does not promise access to other applications' notifications.
- Voice assistance is Android-only and stores its OpenAI credential in Android Keystore.
- Recording defaults are 2-minute segments, 20 GB, and 7 days.
- Every completed milestone must update this file before the next milestone starts.
- Android installs and hardware checks must explicitly target Xperia SO-02J (`BH90CEW05U`), never the connected Pixel.

## Current Phase

Phase 5: Android real-device integration and remaining native adapters.

## Current Task

Validate the remaining native recording, ambient-light, Google OAuth, Android Keystore, and Realtime voice paths on Xperia SO-02J.

## Completion Criteria

- Validate native recording and physical retention behavior on Xperia without deleting user data.
- Validate ambient-light transitions and document credential-dependent Google/voice paths.
- Implement and hardware-test the remaining platform adapters where credentials and hardware are available.

## Completed

- Reviewed `design-plan.md` and converted it into a decision-complete implementation plan.
- Created this checkpoint before any project scaffolding or business code.
- Initialized Git and the Flutter Android/Web plus Rust/Axum monorepo.
- Added the OpenAPI v1 contract and representative JSON fixtures.
- Implemented daemon health, state, notification cursor, white-listed actions, event WebSocket, WebRTC signaling relay, and viewer page.
- Verified `cargo test`: 3 passed.
- Implemented the responsive clock-first Kiosk, progressive detail panels, status-only recording light, Android-only voice status, reminder controls, and settings.
- Implemented ambient-light hysteresis, sunrise/sunset fallback, temporary manual theme overrides, and persistence.
- Verified `flutter analyze`: no issues. Verified theme policy and Kiosk widget tests.
- Added daemon health consumption and offline/online status on the Kiosk.
- Added tested 2-minute segment retention, 20 GB/7-day eviction, and capped upload retry models.
- Added a camera-backed segment recorder using the Android CameraX and Web camera plugin implementations.
- Added Android screen pinning, keep-awake, immersive mode, ambient-light channel, media/location/foreground-service permissions, and one-time geolocation.
- Added Google Calendar/Tasks authorization and refresh client, including task completion.
- Added Android Keystore-backed voice credentials, OpenAI Realtime WebSocket transport, and eight strictly white-listed voice tools.
- Verified `flutter analyze`: no issues. Verified `flutter test`: 8 passed.
- Re-verified `cargo test`: 3 passed.
- Added real OPFS persistence for closed Web segments and persistent application storage for Android segments; retention deletes physical files.
- Added persistent application alarms, nearest-alarm scheduling, full-screen firing, snooze, and dismiss. Flutter tests now pass 9/9.
- Replaced simulated daemon action acceptance with configured command aliases, URL-host allowlists, and fixed macOS/Linux/Windows system adapters. Arbitrary shell input is never evaluated.
- Verified daemon `cargo fmt --check`, `cargo test` (3/3), and strict Clippy.
- Built the Flutter Web release successfully and kept its local server running at http://127.0.0.1:4173/.
- Built the Rust release and kept the daemon running at http://127.0.0.1:43821/.
- Live-verified daemon health/state and confirmed an unconfigured app action returns HTTP 503 instead of a false success.
- Visually verified 1280x800 and 800x1280 layouts, settings panel, light/dark themes, zero page overflow, and zero browser console errors.
- Rebuilt the home as a full-screen centered clock with no reminder list or split layout; proximity-only alarm, calendar, and task indicators now join the compact status dock.
- Added five persisted Material 3 seed palettes, four clock typefaces, and four scheme-derived clock color roles while retaining ambient-light and sunrise/sunset brightness selection.
- Verified `flutter analyze`, all 12 Flutter tests, and the Flutter Web release build. Visually verified 1280x800, 800x1280, and 390x844 layouts, palette/typeface switching, zero scroll overflow, and zero browser console errors.
- Bundled eight cross-platform artistic numeral fonts: Unbounded, Bodoni Moda, Quicksand, Monoton, Bungee Shade, Fascinate Inline, Tourney, and Bruno Ace. The settings panel previews each font with real numerals and persists a 100-900 weight slider.
- Reconfigured Flutter to `/Users/neri/Toolchains/android` with Android Studio JDK 21, installed Android 36, NDK 28.2.13676358, Android 35, and CMake 3.22.1, then built `app-debug.apk` successfully.
- Installed and launched Vivy exclusively through `adb -s BH90CEW05U` on Xperia SO-02J (Android 7/API 24). Verified the Vivy process and focused Activity, no fatal logcat crash, and a correctly rendered centered artistic clock behind the pending camera permission dialog.
- Switched every selectable Material palette to a tonal-spot scheme over a lightly seed-tinted surface, removing the harsh black-or-white appearance in both brightness modes. Verified the result on Xperia in light and dark themes.
- Removed the status container, moved status indicators to the lower-left edge, and corrected the clock's perceived vertical compression on the Xperia panel.
- Redesigned the always-visible date as an editorial day/divider/weekday/month lockup. Normal recording, microphone, and computer indicators now hide while idle; approaching reminders and abnormal states remain visible, while a screen tap reveals the full controls for eight seconds.
- Re-verified the idle and revealed layouts on Flutter Web and Xperia SO-02J, including the full-width header fix, no overlapping controls, and the Xperia-only ADB target. Browser diagnostics reported no warnings or errors.
- Re-verified `flutter analyze`, all 12 Flutter tests, the Flutter Web release build, and the Android debug APK build. Reinstalled the final APK successfully with `adb -s BH90CEW05U install -r`.
- Enlarged the editorial date lockup and moved it to the upper-left, leaving the clock center visually unobstructed; revealed branding now occupies the independent upper-center position.
- Restyled persistent abnormal recording, microphone, and computer states with subdued scheme-derived tertiary/outline colors, smaller icons, and no abnormal glow.
- Added a dedicated full-screen, two-column settings workspace for short landscape displays. On Xperia it simultaneously exposes brightness/palette and all eight typeface previews/weight controls, with independently scrollable columns for remaining options.
- Added an Xperia-equivalent `1280x720 @ 2x` widget regression test. Verified `flutter analyze`, all 13 Flutter tests, Web and Android builds, then installed and visually inspected the final APK on Xperia SO-02J only.
- Flattened the date into a readable upper-left `day · weekday · month` row. Weekday and month now share the same 17sp hierarchy, removing the small stacked month and reducing the header height from 72 to 56 logical pixels.
- Added an Android-native device-motion event channel for optional accelerometer and gyroscope input. The clock filters gravity, combines translation and rotation impulses, caps displacement at 14 pixels, and uses a damped spring to return precisely to center; Web remains stationary.
- Added bounded-motion and gravity-filter unit coverage. Verified `flutter analyze`, all 15 Flutter tests, Web and Android builds, and installed the APK exclusively on Xperia `BH90CEW05U`.
- Visually verified the final horizontal date on the Xperia screen. Android `sensorservice` confirmed Vivy's active BMI160 accelerometer and gyroscope registrations at a 20ms sampling period, with no fatal logcat crash.
- Replaced the hard-coded quarter-turn motion transform with four-way Android display-rotation mapping. Xperia's active `ROTATION_270` now converts natural device axes into screen axes before the clock applies opposite-direction translational inertia.
- Reworked the date as a unified Bodoni Moda `Friday · July 31` line, using one baseline and closely related 28/31sp sizes instead of mixing a 46sp numeral with stacked uppercase sans-serif labels.
- Found and removed an Android 7 incompatibility during real-device validation: `SensorManager.remapCoordinateSystem` expects a rotation matrix, not a raw three-axis vector. The final implementation uses allocation-light manual axis mapping and ran on Xperia without a new crash after clearing the stale system error dialog.
- Preserved the Xperia's 15GB of recordings when the universal APK could not update with only 384MB free. Built and installed the 104MB ARM64-specific debug APK instead; no recording data or preferences were deleted.
- Replaced the previous serif date treatment with a compact Material sans-serif `FRI 31 JUL` lockup whose text, emphasis, and abnormal-state colors follow the active `ColorScheme`.
- Removed the separate header and status band. Date, current and upcoming weather, reminders, device abnormalities, and revealed settings now share one unobtrusive bottom information rail; the central clock grew to a 96% by 78% responsive footprint.
- Added real Open-Meteo hourly forecasts with a 30-minute refresh, current and next-two-hour summaries, a tap-open hourly detail view, and quiet notices for rain, storms, or a material temperature shift.
- Kept location-bearing weather requests on verified HTTPS for Android 7 by adding the official ISRG Root X1 trust anchor instead of downgrading transport security.
- Added hourly forecast parsing and rain-notice tests. Re-verified `flutter analyze`, all 17 Flutter tests, and the Flutter Web release build.
- Built and installed the final 23MB ARMv7 release APK exclusively on Xperia `BH90CEW05U` because its internal storage had fallen to approximately 154MB. Preserved all 15GB of recordings and application preferences.
- Visually verified the final Xperia home screen and full-screen hourly forecast: the clock remains dominant, the bottom rail does not overlap it, theme colors are coherent, and logcat contains no Vivy crash or TLS verification failure.
- Added a one-time, build-gated recording cleanup path that deletes only the native `files/recordings` directory. Ran it on Xperia with a versioned ARMv7 release package; `/data` recovered from 99% full to approximately 30% full (about 15GB free), while theme, location, and other preferences remained intact.
- Consolidated weather advisories, approaching alarms/reminders, and desktop daemon notifications into one quiet, theme-aware status area. Candidates sort by priority and then creation time, keep up to four unresolved items, auto-rotate every five seconds, and advance on tap; the active item opens its relevant detail panel.
- Changed weather presentation from hourly temperatures/icons to sentence-level advisories such as `今天可能下雨`, `明天可能下雨`, or `今天外面气温偏高`, while keeping the forecast parser and secure HTTPS refresh path underneath.
- Increased the bottom information rail's horizontal inset on compact displays from 16 logical pixels to 32 on the left and 28 on the right, visibly moving the status axis away from Xperia's edge.
- Added multi-item rotation and day-level weather advisory tests. Verified `flutter analyze`, all 20 Flutter tests, the Flutter Web release, and the normal ARMv7 release build.
- Reinstalled normal Vivy release version `2003` exclusively on Xperia `BH90CEW05U`; final screenshots show the enlarged clock, inward bottom rail, and sentence-level weather notice. Xperia has approximately 14GB free after the requested recording deletion, and final Vivy logcat has no crash or TLS verification error.
- Added persisted `RecordingSettings` with a 1–20GB cache slider in both portrait and short-landscape settings. The selected limit updates the active recorder and is restored from `SharedPreferences` on launch.
- Made the cache limit physical: startup, cache-limit changes, and every closed segment now scan stored files and remove the oldest files until the byte quota is satisfied. Web storage keeps its existing OPFS path and native Android enforces the quota on the application support directory.
- Replaced the date row with a stable Material sans-serif `date | WEEKDAY | MONTH` lockup using theme outline dividers, consistent baseline alignment, and no hand-written spacing.
- Added cache conversion/widget coverage. Verified `flutter analyze`, all 21 Flutter tests, the Flutter Web release, and the final ARM64 split release.
- Installed the final `arm64-v8a` APK exclusively on Xperia `BH90CEW05U` (`primaryCpuAbi=arm64-v8a`, version `3006`) with approximately 4GB free and no Vivy crash or TLS verification errors. Visually verified the new date lockup, sentence weather notice, and recording-cache setting in the Xperia landscape settings workspace.
- Enlarged the bottom date lockup for distance reading: the day uses 28sp, weekday/month use 18sp, dividers follow the taller baseline, and a bounded `FittedBox` keeps narrow layouts from overflowing. Verified the final Xperia screenshot at `/tmp/vivy-xperia-arm64-date-readable-final.png`.
- Re-ran `flutter analyze` and all 21 Flutter tests, rebuilt Web and ARM64 release artifacts, and installed version `3007` exclusively on `BH90CEW05U` (`primaryCpuAbi=arm64-v8a`) with no Vivy crash or TLS verification errors.
- Added a compact-only 16 logical-pixel inset to the bottom information rail so the date sits farther from Xperia's left edge while the centered clock remains untouched. Rebuilt Web and ARM64 release artifacts, installed version `3008` exclusively on `BH90CEW05U`, and visually verified `/tmp/vivy-xperia-arm64-date-inset-final.png`.
- Replaced the verbose date labels with a large theme-colored numeric `M/d weekday` lockup such as `8/1 6`, reduced its reserved width to 150 logical pixels, and kept the full date in accessibility semantics.
- Added a matching compact-only right inset so the bottom rail stays inside the large clock's horizontal footprint on both sides. Re-ran `flutter analyze` and all 21 tests, rebuilt Web and ARM64 release artifacts, and installed version `3011` exclusively on `BH90CEW05U`; final idle/revealed screenshots are `/tmp/vivy-xperia-arm64-date-rail-symmetric-final.png` and `/tmp/vivy-xperia-arm64-date-rail-symmetric-revealed.png`.
- Replaced the numeric weekday with locale-aware short labels: Chinese `一二三四五六日`, English `MON TUE WED...`, and Japanese `月火水木金土日`. The month/day portion is fixed-width `MM/dd`, producing `08/01 SAT` on the Xperia's English locale. Added mapping tests, re-ran all 23 Flutter tests, rebuilt Web and ARM64 release artifacts, and installed version `3012` exclusively on `BH90CEW05U`; the final screenshot is `/tmp/vivy-xperia-arm64-date-localized-final.png`.
- Separated bottom-date styling from the clock: the date uses neutral `onSurfaceVariant` tones, 30/28sp hierarchy, and the independently persisted `Date type` picker with all eight bundled typefaces. Kept the cache control visible in Xperia landscape settings, re-ran `flutter analyze` and all 23 tests, rebuilt Web and ARM64 release artifacts, and installed version `3013` exclusively on `BH90CEW05U`; the final screenshot is `/tmp/vivy-xperia-arm64-date-styled-final.png`.
- Fixed the information rail geometry after date typeface changes: date, notification, and right status cells share fixed 48px heights while the date keeps a bounded 180 logical-pixel width. Rebuilt and installed version `3014` exclusively on `BH90CEW05U`; the final dark-theme screenshot is `/tmp/vivy-xperia-arm64-rail-aligned-final.png`.
- Added `.github/workflows/android-release.yml`: every push verifies Flutter, builds an ARM64 APK, and publishes a release named `<version>+<short-commit>`. Equal or lower versions become pre-releases; higher versions become the latest formal release. Added release documentation to `README.md`.
- Created the public repository [nerimoe/vivy](https://github.com/nerimoe/vivy), pushed the initial history and the timezone-stable test fix, and verified both GitHub Actions workflows. The first formal latest release is `v1.0.0+e8a75a1` with `vivy-1.0.0+e8a75a1-arm64-v8a.apk`.
- Renamed the Android namespace, application id, and `MainActivity` package to `moe.neri.vivy` while preserving the existing Flutter channel names. Bottom-aligned the date, notification, and right-side status cells in the 60px information rail.
- Re-ran `flutter analyze` and all 23 Flutter tests, built the ARM64 release APK, installed version `3015` exclusively on Xperia `BH90CEW05U` (`primaryCpuAbi=arm64-v8a`), and visually verified `/tmp/vivy-xperia-arm64-package-bottom-final.png`. The new package produced no fatal or TLS errors in logcat.
- Corrected the information rail's visual ink baseline while preserving 48px hit targets: notification content uses an 8.5dp visual offset and status/settings use 3.5dp. Re-ran `flutter analyze` and all 23 Flutter tests, built version `5024`, and explicitly launched `moe.neri.vivy/.MainActivity` on Xperia `BH90CEW05U` (`primaryCpuAbi=arm64-v8a`). Date and status ink both measure `y=687` in `/tmp/vivy-xperia-arm64-bottom-visual-alignment-new-package-final-3024.png`; the revealed rail is `/tmp/vivy-xperia-arm64-bottom-visual-alignment-new-package-revealed-3024.png`.
- Replaced the information rail's fixed visual transforms with one bottom-aligned 48dp content container inside the 60dp rail. Notification text and the page counter now share the date/weekday's 28sp type scale, and status switchers are bottom-anchored without pixel padding. Re-ran `flutter analyze` and all 23 Flutter tests, built version `5025`, and verified `/tmp/vivy-xperia-rail-container-3025.png` plus the revealed state `/tmp/vivy-xperia-rail-container-3025-revealed.png` on `moe.neri.vivy/.MainActivity`; date and status ink both measure `y=687`.

## Next Actions

1. Validate real camera segment recording, retention, and ambient-light transitions on Xperia SO-02J.
2. Configure Google OAuth client IDs and an Android Keystore OpenAI key, then test on Xperia SO-02J.
3. Implement and hardware-test the shared single-capture WebRTC publisher and OS notification adapters on Xperia.

## Blockers And Risks

- The complete roadmap spans platform-native camera, notification, OAuth, WebRTC, and voice integrations; each platform boundary requires real-device validation.
- Chromium media capture requires a secure context in deployment.
- Screen pinning reduces accidental exits but cannot provide Device Owner-level lock-down.
- Shared single-capture WebRTC publication, OS notification adapters, and real microphone/VAD still require platform-specific implementation and hardware validation.
- OPFS persistence is implemented; browser camera permission and a complete 2-minute rotation still require an interactive Chromium permission test.
- The required Android build packages are installed and the APK builds. `flutter doctor` still reports some unrelated Android licenses as unaccepted; Vivy did not accept legal terms automatically.
- Google OAuth needs project-specific Android/Web client IDs. Realtime needs a user-provided API key and microphone hardware; no credentials are committed.
- The recording directory is currently empty after the requested cleanup. Future retention must still reserve operating-system headroom or dynamically cap itself below the configured 20GB limit before extended recording tests.
