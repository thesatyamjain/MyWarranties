# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Fixed
- **Onboarding CTA**: Enabled active click/tap handling on the "Get started" button with tactile spring feedback.
- **Floating Navbar Docking**: Anchored the floating liquid-glass navigation bar to the bottom viewport with safe-area bounds, strict 56 dp height, and max-width constraints to prevent vertical stretching on mobile and web viewports.
- **Mobile Web Viewport**: Added explicit viewport meta tags (`width=device-width, initial-scale=1.0`) in `web/index.html` to eliminate mobile browser scaling artifacts.

---

## [1.1.1] - 2026-10-05

### Added
- **Multi-platform Automated Installers**:
  - Android Universal APK (`my_warranties_android_v1.1.1.apk`)
  - Google Play Store Android App Bundle (`my_warranties_android_v1.1.1.aab`)
  - iOS Release Package archive (`my_warranties_ios_v1.1.1_unsigned.ipa`)
  - Web production bundle (`my_warranties_web_v1.1.1.tar.gz`)
- **Semantic Version Bump Automation**: Added `patch`, `minor`, `major`, and `manual` bump dropdown triggers directly in the GitHub Actions `workflow_dispatch` runner.

### Fixed
- **CI Test Suite**: Fixed calendar leap-year edge cases in `test/widget_test.dart` for deterministic test verification.
- **Cupertino Routing**: Added missing `cupertino.dart` import in `theme.dart` for smooth Apple page transitions.

---

## [1.1.0] - 2026-10-05

### Added
- **BYOK (Bring Your Own Key) Gemini AI**:
  - Secure in-app API key manager in Settings with local persistence via `SharedPreferences`.
  - Fallback pipeline supporting user-provided key or build-time `--dart-define=GEMINI_API_KEY`.
- **Intelligent Warranty Policy Resolution**: Gemini AI extraction for category, brand standard coverage periods, and granular part-level warranties (e.g., motor, compressor, chassis).
- **Apple iOS Design System Polish**:
  - `AppleBounce` tactile spring touch responses for cards, buttons, and CTAs.
  - Smooth gliding indicator pill across the frosted liquid-glass bottom navigation bar.
- **Production Hardening**:
  - Export to PDF and claims utility flow.
  - Multiplatform continuous integration (CI) workflow on GitHub Actions.
  - Open source MIT License, GitHub documentation, and `.gitignore` safety hardening.

---

## [1.0.0] - 2026-10-04

### Added
- **Initial MVP Release**:
  - Bill image scanning, receipt storage, and category categorization.
  - Warranty status engine (Active, Expiring Soon, Expired) with localized countdown calculation.
  - Clean, distraction-free Apple Human Interface design with frosted glass and Cupertino styling.
  - Local SQLite / SharedPreferences data persistence.
