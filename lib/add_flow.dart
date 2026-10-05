import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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
    backgroundColor: Pal.paper,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Pal.r))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
              alignment: Alignment.centerLeft,
              child: Text('Add a bill', style: Theme.of(context).textTheme.headlineSmall)),
          const SizedBox(height: 4),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('Lay it flat in good light. Include the full bill.',
                  style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(height: 12),
          for (final o in const [
            ('camera', CupertinoIcons.camera, 'Scan with camera'),
            ('gallery', CupertinoIcons.photo, 'Choose from gallery'),
            ('multi', CupertinoIcons.photo_on_rectangle, 'Add several bills at once'),
            ('pdf', CupertinoIcons.doc_richtext, 'Import a PDF'),
          ])
            ListTile(
                leading: Icon(o.$2),
                title: Text(o.$3),
                onTap: () => Navigator.pop(context, o.$1)),
        ]),
      ),
    ),
  );
  if (src == null || !context.mounted) return;
  final picker = ImagePicker();
  // maxWidth keeps uploads small for low-end phones and 4G (image compression).
  final List<String> paths;
  if (src == 'pdf') {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    paths = [for (final f in r) if (f.path != null) f.path!];
  } else if (src == 'multi') {
    paths = [for (final x in await picker.pickMultiImage(maxWidth: 1800, imageQuality: 80)) x.path];
  } else {
    final x = await picker.pickImage(
        source: src == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 80);
    paths = [if (x != null) x.path];
  }
  // Bulk: each bill goes through processing and review in turn.
  // ponytail: sequential; backing out of one bill moves to the next.
  for (final p in paths) {
    if (!context.mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProcessingScreen(store: store, file: File(p))));
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
      final ex = await extractBill(widget.file);
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
                    : '${error ?? ''}'.replaceFirst('Bad state: ', ''),
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
    if (manual) conf.updateAll((_, __) => 1); // nothing to doubt when the user types it
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
              printed: i['printed_warranty'] as String?)
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
