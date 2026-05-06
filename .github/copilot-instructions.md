# GitHub Copilot / AI Agent Instructions — dinadrawing

Purpose: short, actionable guidance for AI agents working on this Flutter app.

- **Project type:** Flutter multi-platform app. Entry: `lib/main.dart`.
- **Important files:** `lib/onboarding_page.dart` (onboarding flow), `pubspec.yaml` (assets & deps), `test/widget_test.dart` (basic tests).

Key patterns & gotchas
- The onboarding flow is implemented in `lib/onboarding_page.dart` using a `PageView.builder` and a single `images` list. The code treats indexes 5 and 6 as special: index 5 => Sign Up page, index 6 => Log In page. If you reorder or add images, update those indices and the dot indicator logic accordingly.
- The visual indicator (dots) is generated with `List.generate(5, ...)` — it tracks only the first 5 tutorial pages. Ensure you sync this number with the number of tutorial pages when changing UI flow.
- UI layout: the onboarding screen is wrapped in a centered `Container(width: 375)` (fixed width). Many UI changes assume this fixed width — make responsive updates deliberately.
- Assets are enumerated individually in `pubspec.yaml` (see the `assets:` section). Adding images requires adding each path to `pubspec.yaml` so Flutter includes them.
- Visual constants to reuse: main button color `#F5B335` (defined in `buildMainButton`), logo image `images/logo.png` displayed at height 44.
- Form behaviors: sign-up validation requires non-empty `name`, `username`, `email` and `password.length >= 8`. Login expects non-empty username/email and password. `Continue with Google` is a placeholder (snack bar) — no real auth integration exists.

Developer workflows & run commands
- Install deps: `flutter pub get`.
- Static analysis: `flutter analyze` (or `dart analyze`).
- Run unit/widget tests: `flutter test`.
- Run on desktop (macOS): `flutter run -d macos`.
- Run on device/emulator: `flutter run -d android` or `flutter run -d ios` (iOS requires Xcode & signing).
- Build release artifacts: `flutter build apk`, `flutter build ios`, `flutter build web`.
- Helpful debug flags: `flutter run --verbose` and `flutter logs` (or platform-specific IDE logs).

Conventions & implementation notes
- Minimal third-party deps in `pubspec.yaml` (see `google_fonts`, `cupertino_icons`). For auth or analytics, add explicit packages and update `pubspec.yaml`.
- UI components in `lib/onboarding_page.dart` favor small reusable widget functions (`buildTextField`, `buildPasswordField`, `buildMainButton`, `buildGoogleButton`). Keep changes local and prefer reusing these helpers.
- State is local to the onboarding stateful widget via `TextEditingController` and booleans (no global state management used). When adding persistent auth/session state, add a top-level provider or bloc clearly and document it.

Integration points to watch
- Native folders (`android/`, `ios/`, `macos/`) are present — native changes (plugins, entitlements, signing) live there.
- No authentication backend is wired in the repo; Google sign-in is a UI placeholder. If integrating `google_sign_in`, update `pubspec.yaml` and native config (iOS/Android) accordingly.

What to check before editing UI flow
- Verify `pubspec.yaml` asset entries when adding new images.
- Search for hard-coded indices in `lib/onboarding_page.dart` (e.g., `if (index == 5)`, `goToPage(6)`, `currentIndex < 5`) and update them together.
- Run `flutter analyze` and `flutter test` locally after edits.

If unsure, inspect these files first:
- `lib/onboarding_page.dart` — onboarding logic and UI layout
- `lib/main.dart` — app entry point
- `pubspec.yaml` — assets and dependency list

Ask for feedback: tell me if you'd like expanded guidance (auth integration, responsive refactor, or test coverage additions).
