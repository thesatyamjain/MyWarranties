import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'extractor.dart';
import 'models.dart';
import 'resolver.dart';
import 'store.dart';
import 'theme.dart';

/// Screens 3-5: add bill, processing, review and confirm.
Future<void> startAddFlow(BuildContext context, Store store) async {
  final src = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AddBillSheet(),
  );
  if (src == null || !context.mounted) return;

  if (src == 'manual') {
    final tempDir = await getTemporaryDirectory();
    final placeholder = File('${tempDir.path}/manual_bill_placeholder.jpg');
    if (!await placeholder.exists()) {
      final jpgBytes = base64Decode(
          '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=');
      await placeholder.writeAsBytes(jpgBytes);
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          store: store,
          file: placeholder,
          ex: Extraction({'items': [{}]}),
        ),
      ),
    );
    return;
  }

  final picker = ImagePicker();
  final List<String> paths;
  if (src == 'pdf') {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    paths = [for (final f in r) if (f.path != null) f.path!];
  } else if (src == 'gallery') {
    final multi = await picker.pickMultiImage(maxWidth: 1800, imageQuality: 80);
    paths = [for (final x in multi) x.path];
  } else {
    final x = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      imageQuality: 80,
    );
    paths = [if (x != null) x.path];
  }

  for (final p in paths) {
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(store: store, file: File(p)),
      ),
    );
  }
}

class _AddBillSheet extends StatelessWidget {
  const _AddBillSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Pal.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: Pal.line.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with title and dismiss button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a Bill',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.1,
                        color: Pal.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Instant AI extraction from photos, PDFs, or manual entry.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Pal.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Close',
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Pal.line.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.xmark, size: 13, color: Pal.muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Hero Primary Action: Camera Scanner
          _BentoTile(
            title: 'Scan with Camera',
            subtitle: 'Auto-detects seller, dates, amounts & warranty',
            badge: 'Instant AI',
            icon: CupertinoIcons.camera_fill,
            iconBg: Pal.blue.withValues(alpha: 0.12),
            iconColor: Pal.blue,
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          const SizedBox(height: 12),

          // 2. Secondary Bento Grid (Gallery & PDF)
          Row(
            children: [
              Expanded(
                child: _BentoSquareTile(
                  title: 'Photo Library',
                  subtitle: 'Single or batch images',
                  icon: CupertinoIcons.photo_on_rectangle,
                  iconBg: const Color(0xFF5856D6).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF5856D6),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BentoSquareTile(
                  title: 'Files & PDF',
                  subtitle: 'Invoices & e-receipts',
                  icon: CupertinoIcons.doc_text_fill,
                  iconBg: const Color(0xFF0071A4).withValues(alpha: 0.12),
                  iconColor: const Color(0xFF0071A4),
                  onTap: () => Navigator.pop(context, 'pdf'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Tertiary Action: Direct Manual Entry
          Material(
            color: Pal.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.pop(context, 'manual'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Pal.line.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(CupertinoIcons.square_pencil, size: 16, color: Pal.ink),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter details manually',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Pal.ink,
                            ),
                          ),
                          Text(
                            'Type product info without a bill',
                            style: TextStyle(
                              fontSize: 12,
                              color: Pal.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 14,
                      color: Pal.muted.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _BentoTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Pal.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: Pal.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Pal.muted),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 15,
                color: Pal.muted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoSquareTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _BentoSquareTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Pal.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: Pal.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Pal.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProcessingScreen extends StatefulWidget {
  final Store store;
  final File file;
  const ProcessingScreen({super.key, required this.store, required this.file});
  @override
  State<ProcessingScreen> createState() => _ProcessingState();
}

class _ProcessingState extends State<ProcessingScreen> {
  String? error;
  bool notBill = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => error = null);
    try {
      final ex = await extractBill(widget.file, apiKey: widget.store.userApiKey);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ReviewScreen(store: widget.store, file: widget.file, ex: ex)));
    } on NotABill {
      if (mounted) setState(() => notBill = true);
    } catch (e) {
      // Manual entry is always available (PRD risk table).
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final failed = error != null || notBill;
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(Pal.r),
              child: isPdf(widget.file.path)
                  ? Container(
                      height: 160,
                      width: double.infinity,
                      color: Pal.card,
                      child: const Icon(CupertinoIcons.doc_richtext, size: 56, color: Pal.muted))
                  : Image.file(widget.file, height: 220, fit: BoxFit.cover)),
          const SizedBox(height: 28),
          if (!failed) ...[
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 20),
            Text('Reading your bill', style: t.headlineSmall),
            const SizedBox(height: 6),
            Text('Finding the product, date and warranty. This takes a few seconds.',
                textAlign: TextAlign.center, style: t.bodyMedium),
          ] else ...[
            Text(notBill ? 'That does not look like a bill' : 'Could not read this bill',
                style: t.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
                notBill
                    ? 'Try again with a photo of the full invoice or receipt.'
                    : (error ?? '')
                        .replaceFirst('Bad state: ', '')
                        .replaceFirst('HttpException: ', '')
                        .replaceFirst('StateError: ', '')
                        .replaceFirst('SocketException: ', '')
                        .replaceFirst('ClientException: ', '')
                        .replaceAll(RegExp(r',?\s*uri=https?:\S+'), ''),
                textAlign: TextAlign.center,
                style: t.bodyMedium),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: () => Navigator.pop(context), child: const Text('Try another photo')),
            if (!notBill)
              TextButton(
                  onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ReviewScreen(
                              store: widget.store, file: widget.file, ex: Extraction({'items': [{}]})))),
                  child: const Text('Enter details manually')),
          ],
        ]),
      ),
    );
  }
}

class _Row {
  final String id = const Uuid().v4();
  bool track = true;
  final name = TextEditingController();
  final brand = TextEditingController();
  final model = TextEditingController();
  final serial = TextEditingController();
  final price = TextEditingController();
  String category = 'Other';
  List<Term> terms = [];
  bool confirmedEstimate = false;
  double conf = 1;
  bool get needsConfirm =>
      terms.any((t) => t.source == TermSource.estimated) && !confirmedEstimate;
}

class ReviewScreen extends StatefulWidget {
  final Store store;
  final File file;
  final Extraction ex;
  const ReviewScreen({super.key, required this.store, required this.file, required this.ex});
  @override
  State<ReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends State<ReviewScreen> {
  final seller = TextEditingController(), invoice = TextEditingController(),
      total = TextEditingController();
  DateTime? date;
  late final Map<String, double> conf;
  late final List<_Row> rows;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.ex;
    conf = {for (final k in ['seller', 'invoice_no', 'purchase_date', 'total_amount']) k: ex.conf(k)};
    final manual = ex.raw.isEmpty || ex.items.length == 1 && ex.items.first.isEmpty;
    if (manual) conf.updateAll((_, _) => 1); // nothing to doubt when the user types it
    seller.text = '${ex.val('seller') ?? ''}';
    invoice.text = '${ex.val('invoice_no') ?? ''}';
    total.text = '${ex.val('total_amount') ?? ''}';
    date = DateTime.tryParse('${ex.val('purchase_date')}');
    rows = [
      for (final i in ex.items)
        _Row()
          ..name.text = '${i['product_name'] ?? ''}'
          ..brand.text = '${i['brand'] ?? ''}'
          ..model.text = '${i['model'] ?? ''}'
          ..serial.text = '${i['serial_no'] ?? ''}'
          ..price.text = '${i['price'] ?? ''}'
          ..conf = manual ? 1 : (i['confidence'] as num?)?.toDouble() ?? 0
          ..category = guessCategory('${i['product_name'] ?? ''}')
          ..terms = resolveWarranty(
              name: '${i['product_name'] ?? ''}',
              brand: '${i['brand'] ?? ''}',
              category: guessCategory('${i['product_name'] ?? ''}'),
              printed: i['printed_warranty'] as String?,
              aiTerms: [
                for (final t in (i['standard_warranty_terms'] as List? ?? []))
                  if (t is Map && t['label'] != null && t['months'] != null)
                    Term(
                      '${t['label']}',
                      (t['months'] as num).toInt(),
                      t['source'] == 'estimated' ? TermSource.estimated : TermSource.brand,
                    ),
              ])
    ];
    if (rows.isEmpty) rows.add(_Row());
  }

  String? get dateIssue => date == null ? 'Pick the purchase date' : validateDate(date!);
  bool get dupe => widget.store.hasInvoice(invoice.text.trim());
  bool get canSave =>
      !saving &&
      dateIssue == null &&
      seller.text.trim().isNotEmpty &&
      rows.any((r) => r.track) &&
      rows.where((r) => r.track).every((r) =>
          r.name.text.trim().isNotEmpty && r.terms.isNotEmpty && !r.needsConfirm);

  Future<void> _save() async {
    setState(() => saving = true);
    final billId = const Uuid().v4();
    final img = await widget.store.saveImage(widget.file, billId);
    final bill = Bill(billId, img.path, seller.text.trim(), invoice.text.trim(), date!,
        double.tryParse(total.text) ?? 0, 'INR');
    final items = [
      for (final r in rows.where((r) => r.track))
        Item(r.id, billId, r.name.text.trim(), r.brand.text.trim(), r.model.text.trim(),
            r.serial.text.trim(), r.category, double.tryParse(r.price.text) ?? 0,
            date! /* clock starts at the bill's purchase date */, r.terms)
    ];
    await widget.store.add(bill, items);
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
              onPressed: canSave ? _save : null,
              child: Text(saving ? 'Saving' : 'Save and start countdown')),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        Text('Check what we found', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text('Fields marked amber were hard to read. Edit anything before saving.',
            style: t.bodyMedium),
        if (dupe)
          _Banner('A bill with this invoice number is already saved.'),
        const SizedBox(height: 16),
        _Field('Seller', seller, conf['seller']!, onChanged: () => setState(() {})),
        _Field('Invoice number', invoice, conf['invoice_no']!, onChanged: () => setState(() {})),
        _DateField(
            date: date,
            conf: conf['purchase_date']!,
            issue: dateIssue,
            onPick: (d) => setState(() => date = d)),
        _Field('Total amount (INR)', total, conf['total_amount']!, number: true),
        const SizedBox(height: 12),
        Text('Products on this bill', style: t.titleMedium),
        const SizedBox(height: 8),
        for (final r in rows) _ItemCard(r, onChanged: () => setState(() {})),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Terms and conditions may apply to every warranty.', style: t.bodySmall),
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner(this.text);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Pal.amberBg, borderRadius: BorderRadius.circular(Pal.r)),
        child: Text(text, style: const TextStyle(color: Pal.amber)),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController c;
  final double conf;
  final bool number;
  final VoidCallback? onChanged;
  const _Field(this.label, this.c, this.conf, {this.number = false, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final low = conf < 0.8;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onChanged: (_) => onChanged?.call(),
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: lowDecoration(label, low),
      ),
    );
  }
}

InputDecoration lowDecoration(String label, bool low) => InputDecoration(
      labelText: label,
      helperText: low ? 'Low confidence, please check' : null,
      helperStyle: const TextStyle(color: Pal.amber),
      enabledBorder: low
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(Pal.r),
              borderSide: const BorderSide(color: Pal.amber, width: 1.6))
          : null,
    );

class _DateField extends StatelessWidget {
  final DateTime? date;
  final double conf;
  final String? issue;
  final ValueChanged<DateTime> onPick;
  const _DateField({required this.date, required this.conf, required this.issue, required this.onPick});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(Pal.r),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
                context: context,
                initialDate: date ?? now,
                firstDate: DateTime(now.year - 10),
                lastDate: now);
            if (d != null) onPick(d);
          },
          child: InputDecorator(
            decoration: lowDecoration('Purchase date (warranty starts here)', conf < 0.8)
                .copyWith(errorText: issue),
            child: Text(date == null ? 'Select date' : DateFormat('d MMM yyyy').format(date!)),
          ),
        ),
      );
}

class _ItemCard extends StatefulWidget {
  final _Row r;
  final VoidCallback onChanged;
  const _ItemCard(this.r, {required this.onChanged});
  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  _Row get r => widget.r;

  void _changed() {
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Checkbox(value: r.track, onChanged: (v) {
            r.track = v ?? true;
            _changed();
          }),
          Expanded(child: Text('Track this product', style: t.titleSmall)),
        ]),
        if (r.track) ...[
          _Field('Product name', r.name, r.conf, onChanged: _changed),
          Row(children: [
            Expanded(child: _Field('Brand', r.brand, r.conf)),
            const SizedBox(width: 10),
            Expanded(child: _Field('Model', r.model, r.conf)),
          ]),
          _Field('Serial / IMEI (optional)', r.serial, 1),
          Text('Warranty', style: t.titleSmall),
          const SizedBox(height: 6),
          if (r.terms.isEmpty)
            Text('We could not find a period. Add one below.', style: t.bodyMedium),
          for (final term in r.terms) _TermRow(term, onChanged: () {
            r.confirmedEstimate = false;
            _changed();
          }, onRemove: () {
            r.terms.remove(term);
            _changed();
          }),
          PopupMenuButton<String>(
              onSelected: (label) {
                r.terms.add(Term(label, 12, TermSource.manual));
                _changed();
              },
              itemBuilder: (_) => [
                    for (final l in ['Extended warranty', 'AMC', 'Component', 'Product'])
                      PopupMenuItem(value: l, child: Text(l)),
                  ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(CupertinoIcons.add, size: 18, color: Pal.blue),
                  const SizedBox(width: 6),
                  Text('Add warranty term', style: const TextStyle(color: Pal.blue)),
                ]),
              )),
          if (r.terms.any((x) => x.source == TermSource.estimated))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: r.confirmedEstimate,
              onChanged: (v) {
                r.confirmedEstimate = v ?? false;
                _changed();
              },
              title: const Text('This estimate is right for my product'),
              subtitle: const Text('Estimates must be confirmed before the countdown starts.'),
            ),
        ],
      ]),
    );
  }
}

class _TermRow extends StatelessWidget {
  final Term term;
  final VoidCallback onChanged, onRemove;
  const _TermRow(this.term, {required this.onChanged, required this.onRemove});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(term.label, style: Theme.of(context).textTheme.bodyLarge),
              SourceChip(term.source),
            ]),
          ),
          IconButton(
              tooltip: 'Fewer months',
              onPressed: term.months > 1
                  ? () {
                      term.months--;
                      term.source = term.source == TermSource.bill ? TermSource.manual : term.source;
                      onChanged();
                    }
                  : null,
              icon: const Icon(CupertinoIcons.minus_circled)),
          SizedBox(
              width: 56,
              child: Text('${term.months} mo', textAlign: TextAlign.center)),
          IconButton(
              tooltip: 'More months',
              onPressed: () {
                term.months++;
                term.source = term.source == TermSource.bill ? TermSource.manual : term.source;
                onChanged();
              },
              icon: const Icon(CupertinoIcons.add_circled)),
          IconButton(
              tooltip: 'Remove term',
              onPressed: onRemove,
              icon: const Icon(CupertinoIcons.xmark)),
        ]),
      );
}

class SourceChip extends StatelessWidget {
  final TermSource s;
  const SourceChip(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final est = s == TermSource.estimated;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: est ? Pal.amberBg : Pal.greenBg, borderRadius: BorderRadius.circular(8)),
      child: Text(sourceLabel[s]!,
          style: TextStyle(fontSize: 12, color: est ? Pal.amber : Pal.green)),
    );
  }
}
