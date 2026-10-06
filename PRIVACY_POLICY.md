# Privacy Policy for My Warranties

**Effective Date:** October 6, 2026  
**Developer:** The Software Labs (Satyam Jain)  
**Contact:** creativity.satyamjain@gmail.com  

---

## 1. Overview
**My Warranties** is a privacy-first, offline-capable mobile application designed to help users track their purchases, product warranties, and store receipts. We respect your privacy and believe that your personal purchase records belong exclusively to you.

---

## 2. Information We Collect and Process

### Local-First Data Storage
- All receipts, product photos, invoice numbers, purchase dates, and warranty information you enter are stored locally on your device.
- We do not operate any proprietary backend server that collects, tracks, or stores your warranty database.

### Google Drive Backup & Sync (Optional)
- If you choose to enable the Google Drive Backup feature, My Warranties requests the restricted OAuth scope `https://www.googleapis.com/auth/drive.file`.
- **Scope Limitation:** This scope only allows My Warranties to view and manage files that were created specifically by the My Warranties app (your encrypted/structured backup archive).
- My Warranties **CANNOT** read, modify, view, or delete any of your other private files, documents, or photos in your Google Drive.
- Your Google account credentials are handled securely by Google's native authentication SDK and are never stored on any external server.

### AI Warranty & Receipt Extraction (Optional)
- When you use the automated warranty scan or receipt parsing feature powered by Google Gemini API, the receipt image and relevant text are sent securely to Google's API for the sole purpose of extracting product details, brand, and warranty periods.
- This data is processed transiently and is not used to build user profiles.

---

## 3. Data Sharing & Third Parties
- We **do not** sell, rent, monetize, or share your personal data with any third-party advertisers or data brokers.
- There are no third-party tracking SDKs, ad networks, or telemetry agents embedded in the application.

---

## 4. Data Retention & Deletion
- You have complete control over your data.
- You can delete any product, bill, receipt, or category directly inside the app at any time.
- Uninstalling the app permanently removes all locally stored data from your device.
- If you use Google Drive backup, you can delete your backup file at any time directly through the app's Settings screen or by deleting the app folder from your Google Drive.

---

## 5. Security
We prioritize the security of your data by using local sandboxed storage and Google's official OAuth2 security standards for Drive synchronization.

---

## 6. Changes to This Privacy Policy
We may update this policy periodically to reflect updates in app functionality or legal requirements. Any updates will be posted to this repository.

---

## 7. Contact Us
If you have any questions or concerns regarding this Privacy Policy or your data privacy, please contact:
- **Email:** creativity.satyamjain@gmail.com
- **GitHub:** [https://github.com/thesatyamjain/MyWarranties](https://github.com/thesatyamjain/MyWarranties)
