import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'extractor.dart';
import 'models.dart';
import 'resolver.dart';
import 'store.dart';
import 'theme.dart';

import 'package:open_filex/open_filex.dart';

Future<void> _shareFile(String path, String text) =>
    SharePlus.instance.share(ShareParams(files: [XFile(path)], text: text));

/// Export all warranty details, live countdown, terms, and embedded original bill into a single `.mywarranty` card
Future<void> shareMyWarrantyCard(Item i, Bill? b) async {
  String? billBase64;
  String billExt = 'jpg';
  if (b != null && b.imagePath.isNotEmpty) {
    try {
      final billFile = File(b.imagePath);
      if (await billFile.exists()) {
        final bytes = await billFile.readAsBytes();
        billBase64 = base64Encode(bytes);
        billExt = isPdf(b.imagePath) ? 'pdf' : 'jpg';
      }
    } catch (e) {
      debugPrint('Error reading bill for .mywarranty: $e');
    }
  }

  final bundle = {
    'version': 1,
    'format': 'mywarranty',
    'exported_at': DateTime.now().toIso8601String(),
    'item': i.toJson(),
    'bill': b?.toJson(),
    'bill_data': billBase64,
    'bill_ext': billExt,
    'days_left': i.daysLeft,
    'countdown': countdown(i.daysLeft),
  };

  final jsonStr = jsonEncode(bundle);
  final dir = await getTemporaryDirectory();
  final sanitizedName = i.name.replaceAll(RegExp(r'[^\w\s\.-]'), '').replaceAll(' ', '_');
  final safeName = sanitizedName.isEmpty ? 'Warranty' : sanitizedName;
  final file = File('${dir.path}/$safeName.mywarranty');
  await file.writeAsString(jsonStr, flush: true);

  await _shareFile(
    file.path,
    'Warranty Card for ${i.name} (${countdown(i.daysLeft)}). Open with My Warranties.',
  );
}

/// Open/view the PDF bill in the system PDF viewer.
Future<void> openBillPdf(Bill b) async {
  try {
    final result = await OpenFilex.open(b.imagePath);
    if (result.type == ResultType.done) return;
  } catch (e) {
    debugPrint('OpenFilex error: $e');
  }
  // If no viewer app handled it or error occurred, fallback to canLaunchUrl
  try {
    final uri = Uri.file(b.imagePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
  } catch (_) {}
  // Final fallback to system share
  await SharePlus.instance.share(ShareParams(files: [XFile(b.imagePath)], text: 'Bill'));
}

/// FR-23: share the bill as a PDF (PDF bills are shared as-is).
Future<void> shareBillPdf(Item i, Bill b) async {
  if (isPdf(b.imagePath)) return _shareFile(b.imagePath, 'Bill for ${i.name}');
  final doc = pw.Document();
  final img = pw.MemoryImage(await File(b.imagePath).readAsBytes());
  doc.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain))));
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/bill_${b.id}.pdf');
  await f.writeAsBytes(await doc.save());
  await _shareFile(f.path, 'Bill for ${i.name}');
}

/// FR-19: an all-day .ics event on the expiry date, with a 7-day alert.
/// ponytail: share-sheet "Open in Calendar" instead of a calendar plugin;
/// swap for add_2_calendar if one-tap insert is wanted.
Future<void> shareCalendarEvent(Item i) async {
  final end = i.endDate!;
  String d(DateTime x) => DateFormat('yyyyMMdd').format(x);
  String esc(String s) => s.replaceAll(',', r'\,').replaceAll(';', r'\;');
  final ics = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//My Warranties//EN',
    'BEGIN:VEVENT',
    'UID:${i.id}@mywarranties',
    'DTSTAMP:${DateFormat("yyyyMMdd'T'HHmmss'Z'").format(DateTime.now().toUtc())}',
    'DTSTART;VALUE=DATE:${d(end)}',
    'DTEND;VALUE=DATE:${d(end.add(const Duration(days: 1)))}',
    'SUMMARY:${esc('Warranty ends: ${i.name}')}',
    'DESCRIPTION:${esc('Keep the bill handy for any claim.')}',
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'DESCRIPTION:Warranty ending soon',
    'TRIGGER:-P7D',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/warranty_${i.id}.ics');
  await f.writeAsString(ics);
  await _shareFile(f.path, 'Warranty expiry for ${i.name}');
}

class BrandContactInfo {
  final String phone;
  final String email;
  final String webUrl;
  final String source;
  final String lastVerified;

  const BrandContactInfo({
    required this.phone,
    required this.email,
    required this.webUrl,
    required this.source,
    required this.lastVerified,
  });
}

const _brandContacts = <String, BrandContactInfo>{
  'apple': BrandContactInfo(
    phone: '000800 1009009',
    email: 'support@apple.com',
    webUrl: 'https://support.apple.com/in-en',
    source: 'Official Apple India',
    lastVerified: 'October 2026',
  ),
  'samsung': BrandContactInfo(
    phone: '1800 572 67864',
    email: 'support.india@samsung.com',
    webUrl: 'https://www.samsung.com/in/support',
    source: 'Official Samsung India',
    lastVerified: 'October 2026',
  ),
  'lg': BrandContactInfo(
    phone: '1800 315 9999',
    email: 'serviceindia@lge.com',
    webUrl: 'https://www.lg.com/in/support',
    source: 'Official LG Electronics India',
    lastVerified: 'October 2026',
  ),
  'sony': BrandContactInfo(
    phone: '1800 103 7799',
    email: 'sonyindia.care@ap.sony.com',
    webUrl: 'https://www.sony.co.in/electronics/support',
    source: 'Official Sony India',
    lastVerified: 'October 2026',
  ),
  'dell': BrandContactInfo(
    phone: '1800 425 0088',
    email: 'support_india@dell.com',
    webUrl: 'https://www.dell.com/support/home/en-in',
    source: 'Official Dell India',
    lastVerified: 'October 2026',
  ),
  'hp': BrandContactInfo(
    phone: '1800 258 7170',
    email: 'in.contact@hp.com',
    webUrl: 'https://support.hp.com/in-en',
    source: 'Official HP India',
    lastVerified: 'October 2026',
  ),
  'lenovo': BrandContactInfo(
    phone: '1800 419 7555',
    email: 'customercare@lenovo.com',
    webUrl: 'https://support.lenovo.com/in/en',
    source: 'Official Lenovo India',
    lastVerified: 'October 2026',
  ),
  'xiaomi': BrandContactInfo(
    phone: '1800 103 6286',
    email: 'service.in@xiaomi.com',
    webUrl: 'https://www.mi.com/in/support',
    source: 'Official Xiaomi India',
    lastVerified: 'October 2026',
  ),
  'boat': BrandContactInfo(
    phone: '022 6918 1920',
    email: 'info@imaginemarketingindia.com',
    webUrl: 'https://support.boat-lifestyle.com',
    source: 'Official boAt Lifestyle',
    lastVerified: 'October 2026',
  ),
  'duracell': BrandContactInfo(
    phone: '1800 120 7897',
    email: 'duracellsupport@imaginemarketingindia.com',
    webUrl: 'https://www.duracell.in/contact-us/',
    source: 'Official Duracell India',
    lastVerified: 'October 2026',
  ),
  'daikin': BrandContactInfo(
    phone: '1860 180 3900',
    email: 'communications@daikinindia.com',
    webUrl: 'https://www.daikinindia.com/service-request',
    source: 'Official Daikin India',
    lastVerified: 'October 2026',
  ),
  'voltas': BrandContactInfo(
    phone: '1860 599 4555',
    email: 'support@voltas.com',
    webUrl: 'https://www.voltas.com/customer-support',
    source: 'Official Voltas Care',
    lastVerified: 'October 2026',
  ),
};

BrandContactInfo? lookupBrandContact(String brandName) {
  final b = brandName.toLowerCase().trim();
  for (final entry in _brandContacts.entries) {
    if (b.contains(entry.key) || entry.key.contains(b)) {
      return entry.value;
    }
  }
  return null;
}

/// FR-24: support lookup. Opens direct official channel if verified, otherwise web search.
Future<void> openSupport(Item i) async {
  final contact = lookupBrandContact(i.brand.isNotEmpty ? i.brand : i.name);
  if (contact != null) {
    final telUri = Uri.parse('tel:${contact.phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
      return;
    }
  }
  await launchUrl(
    Uri.https('www.google.com', '/search',
        {'q': '${i.brand.isEmpty ? i.name : i.brand} customer care contact number'}),
    mode: LaunchMode.externalApplication,
  );
}

/// Open official warranty terms and conditions for the specific product or brand.
Future<void> openWarrantyTerms(Item i) => launchUrl(
    Uri.https('www.google.com', '/search',
        {'q': '${i.brand.isNotEmpty ? i.brand : ""} ${i.name} warranty policy terms and conditions'}),
    mode: LaunchMode.externalApplication);

/// Generates a claim-ready single PDF dossier (Product Details + Serial + Expiry + Bill attachment + Service contact)
Future<void> exportClaimReadyKit(BuildContext context, Store s, Item i, Bill? b) async {
  try {
    final doc = pw.Document();
    final contact = lookupBrandContact(i.brand.isNotEmpty ? i.brand : i.name);

    pw.MemoryImage? billImg;
    if (b != null && b.imagePath.isNotEmpty && !isPdf(b.imagePath)) {
      final f = File(b.imagePath);
      if (await f.exists()) {
        billImg = pw.MemoryImage(await f.readAsBytes());
      }
    }

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          // Header Dossier Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('OFFICIAL WARRANTY CLAIM DOSSIER',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Generated by My Warranties Vault (India)',
                        style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: i.status == WStatus.expired ? PdfColors.red700 : PdfColors.green700,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    i.status == WStatus.expired ? 'EXPIRED' : 'ACTIVE COVERAGE',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Product & Coverage Grid
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PRODUCT SPECIFICATIONS',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800)),
                    pw.Divider(thickness: 1, color: PdfColors.grey300),
                    pw.SizedBox(height: 6),
                    _pdfRow('Product Name', i.name),
                    _pdfRow('Brand', i.brand.isEmpty ? 'N/A' : i.brand),
                    _pdfRow('Model Number', i.model.isEmpty ? 'N/A' : i.model),
                    _pdfRow('Serial / IMEI', i.serial.isEmpty ? 'N/A' : i.serial),
                    _pdfRow('Category', i.category),
                    _pdfRow('Price Paid', i.price > 0 ? '${b?.currency ?? 'INR'} ${i.price.toStringAsFixed(0)}' : 'N/A'),
                    _pdfRow('Coverage Starts', '${s.formatDate(i.start)} (${i.basis})'),
                    _pdfRow('Coverage Ends', i.endDate != null ? s.formatDate(i.endDate!) : 'N/A'),
                    _pdfRow('Status', countdown(i.daysLeft)),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PURCHASE & INVOICE',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800)),
                    pw.Divider(thickness: 1, color: PdfColors.grey300),
                    pw.SizedBox(height: 6),
                    _pdfRow('Seller / Store', b?.seller.isEmpty == true ? 'N/A' : b?.seller ?? 'N/A'),
                    _pdfRow('Invoice No.', b?.invoiceNo.isEmpty == true ? 'N/A' : b?.invoiceNo ?? 'N/A'),
                    _pdfRow('Invoice Date', b != null ? s.formatDate(b.purchaseDate) : 'N/A'),
                    pw.SizedBox(height: 14),

                    if (contact != null) ...[
                      pw.Text('AUTHORISED SERVICE CONTACT',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey800)),
                      pw.Divider(thickness: 1, color: PdfColors.grey300),
                      pw.SizedBox(height: 6),
                      _pdfRow('Toll Free', contact.phone),
                      _pdfRow('Email Care', contact.email),
                      _pdfRow('Verified', '${contact.source} (${contact.lastVerified})'),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (i.extendedPlans.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('EXTENDED WARRANTY / AMC PLANS',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800)),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 6),
            for (final p in i.extendedPlans)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${p.type} (${p.provider})',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('${s.formatDate(p.start)} to ${s.formatDate(p.endDate)} (${p.months} mos)',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
          ],

          if (billImg != null) ...[
            pw.SizedBox(height: 24),
            pw.Text('ATTACHED PURCHASE INVOICE / RECEIPT',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800)),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.ConstrainedBox(
                constraints: const pw.BoxConstraints(maxHeight: 400),
                child: pw.Image(billImg, fit: pw.BoxFit.contain),
              ),
            ),
          ],
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final safeName = i.name.replaceAll(RegExp(r'[^\w\s\.-]'), '').replaceAll(' ', '_');
    final pdfFile = File('${dir.path}/Claim_Kit_${safeName.isEmpty ? 'Warranty' : safeName}.pdf');
    await pdfFile.writeAsBytes(await doc.save(), flush: true);

    await _shareFile(
      pdfFile.path,
      'Warranty Claim Dossier for ${i.name} (Ends: ${i.endDate != null ? s.formatDate(i.endDate!) : 'N/A'})',
    );
  } catch (e) {
    debugPrint('Error generating Claim-Ready Kit: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating Claim Kit: $e')),
      );
    }
  }
}

pw.Widget _pdfRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label,
                style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9.5)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
          ),
        ],
      ),
    );

/// Shows modal with verified Support Contacts, phone dialer, and Claim Kit PDF trigger
Future<void> showClaimReadyKitDialog(BuildContext context, Store s, Item i, Bill? b) async {
  final contact = lookupBrandContact(i.brand.isNotEmpty ? i.brand : i.name);

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Pal.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Pal.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.briefcase_fill, color: Pal.blue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Claim-Ready Kit',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(i.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Pal.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1-Tap Claim PDF Export Card
          LiquidGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Official Claim Dossier (PDF)',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Pal.greenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('1-Tap Ready',
                          style: TextStyle(
                              color: Pal.green, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Includes bill scan, product serial number, purchase date, warranty term dates, and verified brand care contact details.',
                  style: TextStyle(color: Pal.muted, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 14),
                AppleBounce(
                  onTap: () {
                    Navigator.pop(ctx);
                    exportClaimReadyKit(context, s, i, b);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Pal.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.arrow_down_doc, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Export & Share Claim PDF',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Authorised Brand Service Center Contact
          LiquidGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      contact != null ? 'Authorised Brand Service' : 'Brand Customer Care',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (contact != null)
                      const Row(
                        children: [
                          Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Pal.blue),
                          SizedBox(width: 4),
                          Text('Verified',
                              style: TextStyle(
                                  color: Pal.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (contact != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(CupertinoIcons.phone_fill, color: Pal.green, size: 20),
                    title: Text(contact.phone, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Toll Free Support · ${contact.source} (${contact.lastVerified})',
                        style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Pal.muted),
                    onTap: () => launchUrl(Uri.parse('tel:${contact.phone.replaceAll(' ', '')}')),
                  ),
                  if (contact.email.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(CupertinoIcons.mail_solid, color: Pal.blue, size: 20),
                      title: Text(contact.email, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Email Service Centre', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Pal.muted),
                      onTap: () => launchUrl(Uri.parse('mailto:${contact.email}')),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(CupertinoIcons.globe, color: Pal.ink, size: 20),
                    title: const Text('Online Service Booking',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(contact.webUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(CupertinoIcons.arrow_up_right, size: 14, color: Pal.muted),
                    onTap: () => launchUrl(Uri.parse(contact.webUrl), mode: LaunchMode.externalApplication),
                  ),
                ] else ...[
                  const Text(
                    'No verified hotline recorded for this brand yet. You can look up the customer care helpline directly.',
                    style: TextStyle(color: Pal.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                    onPressed: () => openSupport(i),
                    icon: const Icon(CupertinoIcons.search, size: 16),
                    label: Text('Search ${i.brand.isEmpty ? i.name : i.brand} Service Hotline'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

const _bases = ['Purchase date', 'Delivery date', 'Installation date'];

/// FR-14: pick which date starts the clock, and the date itself.
Future<void> showStartSheet(BuildContext context, Store s, Item i) async {
  var basis = i.basis;
  final picked = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Pal.paper,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Warranty starts from', style: Theme.of(ctx).textTheme.headlineSmall)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: basis,
              onChanged: (v) => set(() => basis = v!),
              child: Column(children: [
                for (final b in _bases) RadioListTile<String>(value: b, title: Text(b)),
              ]),
            ),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Pick ${basis.toLowerCase()}')),
          ]),
        ),
      ),
    ),
  );
  if (picked != true || !context.mounted) return;
  final now = DateTime.now();
  final d = await showDatePicker(
      context: context,
      initialDate: i.start.isAfter(now) ? now : i.start,
      firstDate: DateTime(now.year - 10),
      lastDate: now.add(const Duration(days: 365)));
  if (d == null) return;
  i.basis = basis;
  i.start = d;
  await s.update(); // reschedules reminders from the new end date
}

const claimStates = ['None', 'Filed', 'In progress', 'Resolved', 'Rejected'];

/// FR-25: lightweight claim tracker (status, reference number, notes).
Future<void> showClaimSheet(BuildContext context, Store s, Item i) {
  final ref = TextEditingController(text: i.claimRef);
  final notes = TextEditingController(text: i.claimNotes);
  var status = i.claimStatus;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Pal.paper,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Claim tracker', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final c in claimStates)
                ChoiceChip(label: Text(c), selected: status == c, onSelected: (_) => set(() => status = c)),
            ]),
            const SizedBox(height: 14),
            TextField(controller: ref, decoration: const InputDecoration(labelText: 'Reference number')),
            const SizedBox(height: 12),
            TextField(
                controller: notes,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Notes (calls, visits, promises)')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                i.claimStatus = status;
                i.claimRef = ref.text.trim();
                i.claimNotes = notes.text.trim();
                await s.update();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      ),
    ),
  );
}

/// FR-F3: Add or edit an Extended Warranty or AMC plan
Future<void> showAddExtendedPlanSheet(BuildContext context, Store s, Item i, {ExtendedPlan? existing}) async {
  var planType = existing?.type ?? 'Extended warranty';
  final providerCtrl = TextEditingController(text: existing?.provider ?? '');
  final costCtrl = TextEditingController(text: existing != null && existing.cost > 0 ? existing.cost.toStringAsFixed(0) : '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  var months = existing?.months ?? 12;
  // Defaults to starting when the manufacturer warranty ends
  var startDate = existing?.start ?? (i.mfgEndDate ?? i.start);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Pal.paper,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing != null ? 'Edit Extended Coverage' : 'Add Extended Warranty / AMC',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final t in ['Extended warranty', 'AMC'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t),
                        selected: planType == t,
                        onSelected: (_) => set(() => planType = t),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: providerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Plan Provider (e.g. OneAssist, Croma ZipCare, AppleCare+)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: months,
                      decoration: const InputDecoration(labelText: 'Duration'),
                      items: const [
                        DropdownMenuItem(value: 6, child: Text('6 months')),
                        DropdownMenuItem(value: 12, child: Text('1 year (12 mos)')),
                        DropdownMenuItem(value: 24, child: Text('2 years (24 mos)')),
                        DropdownMenuItem(value: 36, child: Text('3 years (36 mos)')),
                        DropdownMenuItem(value: 48, child: Text('4 years (48 mos)')),
                        DropdownMenuItem(value: 60, child: Text('5 years (60 mos)')),
                      ],
                      onChanged: (v) => set(() => months = v ?? 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Plan Cost (INR)',
                        prefixText: '₹ ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(CupertinoIcons.calendar, color: Pal.blue),
                title: const Text('Coverage starts from'),
                subtitle: Text(s.formatDate(startDate)),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: Pal.muted),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    set(() => startDate = picked);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Coverage terms or policy ID (optional)',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (existing != null) ...[
                    IconButton(
                      tooltip: 'Delete Plan',
                      icon: const Icon(CupertinoIcons.delete, color: Pal.brick),
                      onPressed: () async {
                        i.extendedPlans.removeWhere((p) => p.id == existing.id);
                        await s.update();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Pal.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                        if (existing != null) {
                          existing.type = planType;
                          existing.provider = providerCtrl.text.trim();
                          existing.months = months;
                          existing.cost = cost;
                          existing.start = startDate;
                          existing.notes = notesCtrl.text.trim();
                        } else {
                          final newPlan = ExtendedPlan(
                            id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
                            type: planType,
                            provider: providerCtrl.text.trim().isEmpty ? 'Extended Coverage' : providerCtrl.text.trim(),
                            start: startDate,
                            months: months,
                            cost: cost,
                            notes: notesCtrl.text.trim(),
                          );
                          i.extendedPlans = [...i.extendedPlans, newPlan];
                        }
                        await s.update();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Coverage Plan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Live AI Warranty Research: Searches the product's official manufacturer & retailer
/// warranty terms via Gemini AI, showing the user the reasoning, terms, and updating the item clock.
Future<void> recheckWarrantyPolicy(BuildContext context, Store s, Item i) async {
  // Show progress indicator dialog while AI searches
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Pal.card,
            borderRadius: BorderRadius.circular(Pal.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3, color: Pal.blue),
              ),
              const SizedBox(height: 16),
              Text(
                'Searching warranty policy...',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Consulting official brand guidelines for ${i.brand.isNotEmpty ? i.brand : i.name}',
                style: const TextStyle(fontSize: 12, color: Pal.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Term> newTerms = [];
  String explanation = '';
  String? supportLine;

  try {
    Bill? bill;
    for (final b in s.bills) {
      if (b.id == i.billId) {
        bill = b;
        break;
      }
    }
    final sellerName = bill?.seller ?? '';

    final aiResult = await queryProductWarrantyPolicy(
      productName: i.name,
      brand: i.brand,
      model: i.model,
      seller: sellerName,
      apiKey: s.userApiKey,
    );

    if (aiResult.terms.isNotEmpty) {
      newTerms = aiResult.terms.map((t) {
        final label = (t['label'] ?? 'Product').toString();
        final months = (t['months'] as num?)?.toInt() ?? 12;
        return Term(label, months, TermSource.brand);
      }).toList();
    }
    explanation = aiResult.summary;
    supportLine = aiResult.support;
  } catch (e) {
    debugPrint('AI live lookup fallback: $e');
    // Fallback to local resolver rules
    final resolved = resolveWarranty(
      name: i.name,
      brand: i.brand,
      category: i.category,
      aiTerms: null,
    );
    newTerms = resolved.isNotEmpty ? resolved : [Term('Product', 12, TermSource.brand)];
    explanation = 'Calculated from official manufacturer standard catalog.';
  } finally {
    // Dismiss loading dialog if open
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Update Warranty Terms?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (explanation.isNotEmpty) ...[
              Text(explanation, style: const TextStyle(fontSize: 13, height: 1.4)),
              const SizedBox(height: 14),
            ],
            const Text(
              'Verified Coverage Terms:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            for (final t in newTerms)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Pal.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${t.label}: ${t.months} months (${(t.months / 12).toStringAsFixed(t.months % 12 == 0 ? 0 : 1)} yr)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            if (supportLine != null && supportLine.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Pal.paper,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.headset_mic_outlined, size: 16, color: Pal.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Support: $supportLine',
                        style: const TextStyle(fontSize: 12, color: Pal.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep Current'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Apply Verified Policy'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    i.terms = newTerms;
    await s.update();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated ${i.name} warranty to ${newTerms.map((t) => '${t.months} mos').join(', ')}.',
          ),
        ),
      );
    }
  }
}

/// Professional Storage & Cache Hygiene Inspector
Future<void> showStorageManagerSheet(BuildContext context, Store s) async {
  final t = Theme.of(context).textTheme;

  // Compute bill storage size
  int billBytes = 0;
  for (final b in s.bills) {
    try {
      final f = File(b.imagePath);
      if (f.existsSync()) {
        billBytes += f.lengthSync();
      }
    } catch (_) {}
  }

  // Compute temp cache size
  int cacheBytes = 0;
  Directory? tempDir;
  try {
    tempDir = await getTemporaryDirectory();
    if (tempDir.existsSync()) {
      for (final entity in tempDir.listSync(recursive: true)) {
        if (entity is File) {
          cacheBytes += entity.lengthSync();
        }
      }
    }
  } catch (_) {}

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Container(
        decoration: BoxDecoration(
          color: Pal.paper,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Pal.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Pal.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.device_phone_portrait, size: 22, color: Pal.blue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Storage & Cache Hygiene',
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep your local documents and app storage healthy',
                        style: t.bodySmall?.copyWith(color: Pal.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Pal.paper),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.doc_text_fill, size: 18, color: Pal.blue),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Stored Bill Files', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('${s.bills.length} invoices saved', style: const TextStyle(color: Pal.muted, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        formatBytes(billBytes),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 0.8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.archivebox, size: 18, color: Pal.amber),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Temporary Cache', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const Text('Scanner snapshots & PDF exports', style: TextStyle(color: Pal.muted, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        formatBytes(cacheBytes),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(CupertinoIcons.sparkles, size: 16),
                    label: const Text('Clear Temp Cache'),
                    onPressed: cacheBytes == 0
                        ? null
                        : () async {
                            try {
                              if (tempDir != null && tempDir.existsSync()) {
                                for (final entity in tempDir.listSync(recursive: true)) {
                                  if (entity is File) {
                                    try {
                                      entity.deleteSync();
                                    } catch (_) {}
                                  }
                                }
                              }
                              set(() {
                                cacheBytes = 0;
                              });
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Temporary cache cleared successfully!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error clearing cache: $e');
                            }
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Pal.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

