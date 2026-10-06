# My Warranties

[![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Release](https://img.shields.io/badge/Release-v1.1.7-blue.svg)](https://github.com/thesatyamjain/MyWarranties/releases)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-green.svg)](https://flutter.dev)

A modern, privacy-first Flutter application crafted to organize purchase invoices, extract warranty information using Google Gemini AI, calculate countdowns, and schedule offline alerts before warranties expire.

Designed with an Apple-inspired glass interface, tactile spring interactions, and zero server costs.

---

## Key Highlights

- **Bento Vault UI**: Apple-grade grouped styling (`#F2F2F7` paper background), hero protection overview, live coverage metrics, category chips, and a floating frosted-glass gliding navigation pill.
- **Intelligent Invoice Extraction (Gemini AI)**: Scans camera captures, photo library receipts, and high-resolution PDF bills. Extracts seller, invoice number, items, purchase dates, prices, and component warranties.
- **Multi-Tier Warranty Resolution Engine**: Automatically maps standard Indian brand policies (e.g., 1 yr product + 2 yr TV panel, 1 yr AC + 10 yr compressor) with instant confirmation and no validation barriers.
- **Personal Google Drive Cloud Sync**: 1-tap backup and restore directly into your personal Google Drive (`My Warranties Vault` folder). Your bills never touch any third-party database.
- **Android Auto-Backup Ready**: Native integration with Android Cloud Backup rules (`android:allowBackup="true"`) to survive accidental app uninstalls.
- **Home Screen AppWidget**: Native Android home widget bridging warranty status and upcoming expirations directly to your home screen.
- **Indian Date Formats**: First-class support for Indian date conventions (`DD/MM/YY`, `DD/MM/YYYY`, `DD-MM-YYYY`, `D MMM YYYY`, `DD MMMM YYYY`, `YYYY-MM-DD`) customizable from Settings.
- **Complete Claim & Support Suite**:
  - Direct customer care search for major consumer brands.
  - One-tap share of original invoice PDFs with authorized service centers.
  - Interactive Claim Tracker (Status, Reference ID, Service notes).
  - Add expiration alerts directly to device calendar (`.ics`).

---

## Architecture & Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **AI Engine**: Google Gemini API via REST (`gemini-2.5-flash`, `gemini-1.5-flash` with dynamic fallback)
- **Cloud Sync**: Personal Google Drive API (`googleapis`, `google_sign_in`, `drive.file` privacy scope)
- **Native Widgets**: Android AppWidgetProvider (`HomeWidgetProvider.kt`) via MethodChannel
- **Local Persistence**: `SharedPreferences` + `path_provider` (offline-first)
- **Notifications**: `flutter_local_notifications` + `timezone`
- **Typography & Icons**: Satoshi / Geist display scale, Cupertino Icons, Phosphor Icons
- **Document Handling**: `pdf`, `open_filex`, `share_plus`, `url_launcher`

---

## 5-Tier Warranty Resolution Engine

```
[Invoice Image / PDF]
         │
         ▼
[Gemini AI Vision & OCR]
         │
         ├──> 1. Printed Warranty on Invoice -> (Source: From bill)
         │
         ├──> 2. Brand Manufacturer Policy    -> (Source: Brand policy)
         │         (e.g., Sony, Samsung, Apple, LG, BoAt)
         │
         ├──> 3. Curated Indian Brand Matrix  -> (Component-level split)
         │
         └──> 4. Consumer Category Standard   -> (Source: Estimated)
```

Older saved items can be refreshed anytime in 1 tap using **"Sync with Brand Policy"** in the product detail view.

---

## Getting Started

### Prerequisites

- Flutter SDK (3.11.4 or higher)
- Android Studio / Xcode (for mobile builds)
- Google Gemini API Key ([Get a free key from Google AI Studio](https://aistudio.google.com/))

### Setup & Run

1. **Clone the repository**:
   ```bash
   git clone https://github.com/thesatyamjain/MyWarranties.git
   cd MyWarranties
   ```

2. **Fetch dependencies**:
   ```bash
   flutter pub get
   ```

3. **Launch the application**:
   - **With in-app API key configuration (Recommended)**:
     ```bash
     flutter run
     ```
     *Navigate to Settings $\to$ Gemini AI Configuration $\to$ Tap "Add Key" to test and save your key.*

   - **With build-time environment variable**:
     ```bash
     flutter run --dart-define=GEMINI_API_KEY=your_gemini_api_key_here
     ```

---

## Automated Tests

Run the unit and widget smoke test suite:

```bash
flutter test
```

---

## Production Build

### Android APK / App Bundle
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS (macOS required)
```bash
flutter build ipa --release
```

### Web
```bash
flutter build web --release
```

---

## Privacy & Security

- **Zero Third-Party Storage**: We do not host your bills or data on external databases.
- **Your Personal Drive**: Cloud backups go directly into your own Google Drive account under an isolated app folder.
- **BYOK (Bring Your Own Key)**: Gemini API keys are encrypted and stored locally on your device.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Built by [The Software Co.](https://thesoftwareco.pages.dev)
