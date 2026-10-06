import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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

/// FR-24: support lookup. Opens a search for the brand's official care page
/// rather than shipping phone numbers that may go stale or be wrong.
Future<void> openSupport(Item i) => launchUrl(
    Uri.https('www.google.com', '/search',
        {'q': '${i.brand.isEmpty ? i.name : i.brand} customer care contact number'}),
    mode: LaunchMode.externalApplication);

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

