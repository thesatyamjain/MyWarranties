# My Warranties

An Apple-inspired, cross-platform (iOS, Android, Web) Flutter application designed to track purchase bills, extract item details using Gemini AI, automatically calculate warranty countdowns, schedule smart offline alerts, and streamline warranty claims.

---

## ✨ Features

- **Apple-Inspired Design**:
  - Pure grouped styling (`#F2F2F7` paper background, borderless cards, iOS blue `#007AFF`).
  - Frosted glass navbar with an animated gliding pill indicator.
  - Tactile spring micro-interactions (`AppleBounce`) with zero boilerplate.
  
- **Intelligent Bill Recognition (Gemini AI)**:
  - Powered by Google Gemini (`gemini-2.5-flash`).
  - Supports multi-format invoices: Camera photos, Gallery, Multi-image bills, and PDF documents.
  - Rejects non-bill images and extracts seller, invoice number, items, purchase date, serial numbers, and printed warranty terms.

- **5-Tier Warranty Resolution Engine**:
  - `Bill Printed Warranty` $\to$ `AI Brand Policy Lookup` $\to$ `Curated Brand Table` $\to$ `Category Estimates` $\to$ `Manual Entry`.
  - Supports component-level breakdowns (e.g. TV: 1 yr product, 2 yr panel; AC/Fridge: 1 yr product, 10 yr compressor/motor).

- **Bring Your Own API Key (BYOK)**:
  - Configure and persist your own Google Gemini API key directly from the Settings screen.
  - Key stays local to your device using secure local storage.

- **Offline-First & Smart Reminders**:
  - 100% offline countdown calculations and local push notifications (`flutter_local_notifications`).
  - Customizable alert intervals (60, 30, 14, 7, 3, 1, or 0 days before expiration).

- **Warranty Claim & Support Suite**:
  - **Export Claim PDF**: Generates branded claim sheets bundled with purchase metadata and invoice images.
  - **Add to Calendar**: Exports `.ics` files configured with pre-expiration notifications.
  - **Direct Support Finder**: One-tap search for official brand customer care portals.
  - **Interactive Claim Tracker**: Track claim status (Initiated, Pickup scheduled, Under repair, Completed).

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **AI / LLM**: Google Gemini (`gemini-2.5-flash`)
- **Storage**: Local-first (`SharedPreferences`, `path_provider`)
- **Notifications**: `flutter_local_notifications` with `timezone`
- **Design & Icons**: Cupertino transitions, Phosphor Icons (`phosphor_flutter`), custom liquid glass and spring physics
- **Exporting**: `pdf`, `share_plus`, `url_launcher`

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.11.4 or higher)
- Google Gemini API Key ([Get one for free at Google AI Studio](https://aistudio.google.com/))

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/<your-username>/my_warranties.git
   cd my_warranties
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:

   - **Option A: With user-provided API key (Recommended)**:
     ```bash
     flutter run
     ```
     *Then open Settings inside the app $\to$ tap **Add Key** under Gemini AI Configuration $\to$ paste your key.*

   - **Option B: With build-time API key**:
     ```bash
     flutter run --dart-define=GEMINI_API_KEY=your_gemini_api_key_here
     ```

---

## 🧪 Testing

Execute the unit and smoke tests:

```bash
flutter test
```

---

## 📦 Production Builds

### Web
```bash
flutter build web --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS (macOS only)
```bash
flutter build ipa --release
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
