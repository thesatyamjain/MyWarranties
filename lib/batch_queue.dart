import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'add_flow.dart';
import 'extractor.dart';
import 'models.dart';
import 'resolver.dart';
import 'store.dart';
import 'theme.dart';

enum BatchItemStatus {
  queued,
  processing,
  readyToReview,
  needsAttention,
  failed,
  confirmed,
}

class BatchBillItem {
  final String id;
  final String filePath;
  BatchItemStatus status;
  Extraction? extraction;
  String? error;
  DateTime createdAt;

  BatchBillItem({
    required this.id,
    required this.filePath,
    this.status = BatchItemStatus.queued,
    this.extraction,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isHighConfidence {
    if (extraction == null) return false;
    final sellerConf = extraction!.conf('seller');
    final dateConf = extraction!.conf('purchase_date');
    final totalConf = extraction!.conf('total_amount');
    final itemsConf = extraction!.items.isNotEmpty
        ? extraction!.items.every((it) => ((it['confidence'] as num?)?.toDouble() ?? 0) >= 0.75)
        : false;
    return sellerConf >= 0.75 && dateConf >= 0.75 && totalConf >= 0.70 && itemsConf;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': filePath,
        'status': status.name,
        'raw': extraction?.raw,
        'error': error,
        'created': createdAt.toIso8601String(),
      };

  factory BatchBillItem.fromJson(Map<String, dynamic> j) => BatchBillItem(
        id: j['id'],
        filePath: j['path'],
        status: BatchItemStatus.values.byName(j['status'] ?? 'queued'),
        extraction: j['raw'] != null ? Extraction(Map<String, dynamic>.from(j['raw'])) : null,
        error: j['error'],
        createdAt: DateTime.tryParse(j['created'] ?? '') ?? DateTime.now(),
      );
}

class BatchQueueController extends ChangeNotifier {
  static final BatchQueueController instance = BatchQueueController._();
  BatchQueueController._();

  final List<BatchBillItem> items = [];
  bool _isProcessing = false;
  static const _storageKey = 'batch_upload_queue_v1';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_storageKey);
      if (raw != null) {
        final List list = jsonDecode(raw);
        items.clear();
        for (final itemJson in list) {
          final item = BatchBillItem.fromJson(Map<String, dynamic>.from(itemJson));
          if (File(item.filePath).existsSync()) {
            items.add(item);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading batch queue: $e');
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = items.map((i) => i.toJson()).toList();
      await p.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving batch queue: $e');
    }
  }

  Future<void> enqueueFiles(List<String> paths, Store store) async {
    for (final path in paths) {
      if (items.any((it) => it.filePath == path)) continue;
      items.add(BatchBillItem(
        id: const Uuid().v4(),
        filePath: path,
      ));
    }
    await save();
    notifyListeners();
    processNext(store);
  }

  Future<void> processNext(Store store) async {
    if (_isProcessing) return;
    final next = items.where((i) => i.status == BatchItemStatus.queued).firstOrNull;
    if (next == null) {
      _isProcessing = false;
      return;
    }

    _isProcessing = true;
    next.status = BatchItemStatus.processing;
    notifyListeners();

    try {
      final extractor = const DefaultBillExtractor();
      final ext = await extractor.extract(File(next.filePath), apiKey: store.userApiKey);
      next.extraction = ext;

      // Duplicate check: check if already exists in store
      final inv = ext.val('invoice_no')?.toString() ?? '';
      if (store.hasInvoice(inv)) {
        next.status = BatchItemStatus.needsAttention;
        next.error = 'Duplicate invoice #$inv already saved in Vault';
      } else if (next.isHighConfidence) {
        next.status = BatchItemStatus.readyToReview;
      } else {
        next.status = BatchItemStatus.needsAttention;
      }
    } catch (e) {
      next.status = BatchItemStatus.failed;
      next.error = e.toString();
    } finally {
      await save();
      _isProcessing = false;
      notifyListeners();
      // Continue next item in background queue
      processNext(store);
    }
  }

  Future<void> remove(BatchBillItem item) async {
    items.removeWhere((i) => i.id == item.id);
    await save();
    notifyListeners();
  }

  Future<void> clearConfirmed() async {
    items.removeWhere((i) => i.status == BatchItemStatus.confirmed);
    await save();
    notifyListeners();
  }
}

/// Screen showing the Batch Upload review queue with statuses & "Confirm All High-Confidence"
class BatchQueueScreen extends StatefulWidget {
  final Store store;
  const BatchQueueScreen({super.key, required this.store});

  @override
  State<BatchQueueScreen> createState() => _BatchQueueScreenState();
}

class _BatchQueueScreenState extends State<BatchQueueScreen> {
  final _ctrl = BatchQueueController.instance;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pending = _ctrl.items.where((i) => i.status != BatchItemStatus.confirmed).toList();
    final highConf = pending.where((i) => i.status == BatchItemStatus.readyToReview && i.isHighConfidence).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Review Queue'),
        actions: [
          if (highConf.isNotEmpty)
            TextButton(
              onPressed: () => _confirmAllHighConfidence(highConf),
              child: Text('Confirm All (${highConf.length})'),
            ),
        ],
      ),
      body: pending.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Pal.greenBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(CupertinoIcons.checkmark_alt, size: 32, color: Pal.green),
                    ),
                    const SizedBox(height: 16),
                    Text('Batch Queue Clean', style: t.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'All uploaded bills have been processed and confirmed into your vault.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: pending.length,
              itemBuilder: (ctx, idx) {
                final item = pending[idx];
                return _BatchItemCard(
                  item: item,
                  store: widget.store,
                  onReview: () => _openReview(item),
                  onDismiss: () => _ctrl.remove(item),
                );
              },
            ),
    );
  }

  Future<void> _openReview(BatchBillItem item) async {
    if (item.extraction == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          store: widget.store,
          file: File(item.filePath),
          ex: item.extraction!,
        ),
      ),
    );
    // Mark as confirmed once reviewed and saved
    item.status = BatchItemStatus.confirmed;
    await _ctrl.save();
    setState(() {});
  }

  Future<void> _confirmAllHighConfidence(List<BatchBillItem> list) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm ${list.length} Bills?'),
        content: const Text(
          'These bills have high extraction confidence across seller, invoice date, amounts, and warranty terms. They will be saved to your vault immediately.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Review One by One')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm All')),
        ],
      ),
    );

    if (ok != true) return;

    for (final item in list) {
      try {
        final ex = item.extraction!;
        final billId = const Uuid().v4();
        final savedFile = await widget.store.saveImage(File(item.filePath), billId);
        final bill = Bill(
          billId,
          savedFile.path,
          ex.val('seller') ?? '',
          ex.val('invoice_no') ?? '',
          DateTime.tryParse(ex.val('purchase_date') ?? '') ?? DateTime.now(),
          (ex.val('total_amount') as num?)?.toDouble() ?? 0.0,
          ex.raw['total_amount']?['currency'] ?? 'INR',
        );

        final items = <Item>[];
        for (final r in ex.items) {
          final name = r['product_name'] ?? 'Product';
          final brand = r['brand'] ?? '';
          final category = guessCategory(name);
          final terms = resolveWarranty(
            name: name,
            brand: brand,
            category: category,
            printed: r['printed_warranty'],
          );
          items.add(Item(
            const Uuid().v4(),
            bill.id,
            name,
            brand,
            r['model'] ?? '',
            r['serial_no'] ?? '',
            category,
            (r['price'] as num?)?.toDouble() ?? 0.0,
            bill.purchaseDate,
            terms,
          ));
        }

        await widget.store.add(bill, items);
        item.status = BatchItemStatus.confirmed;
      } catch (e) {
        debugPrint('Error auto-confirming batch bill: $e');
      }
    }

    await _ctrl.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully confirmed ${list.length} bills into Vault')),
      );
      setState(() {});
    }
  }
}

class _BatchItemCard extends StatelessWidget {
  final BatchBillItem item;
  final Store store;
  final VoidCallback onReview;
  final VoidCallback onDismiss;

  const _BatchItemCard({
    required this.item,
    required this.store,
    required this.onReview,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final ex = item.extraction;
    final title = ex?.items.firstOrNull?['product_name'] ?? (ex?.val('seller') ?? 'Bill Document');
    final seller = ex?.val('seller') ?? '';
    final dateStr = ex?.val('purchase_date') ?? '';

    final (statusLabel, statusColor, statusBg, statusIcon) = switch (item.status) {
      BatchItemStatus.queued => ('In Queue', Pal.muted, Pal.paper, CupertinoIcons.clock),
      BatchItemStatus.processing => ('Analyzing AI...', Pal.blue, Pal.blue.withValues(alpha: 0.12), CupertinoIcons.sparkles),
      BatchItemStatus.readyToReview => ('Ready to Review', Pal.green, Pal.greenBg, CupertinoIcons.checkmark_alt),
      BatchItemStatus.needsAttention => ('Needs Attention', Pal.amber, Pal.amberBg, CupertinoIcons.exclamationmark_triangle),
      BatchItemStatus.failed => ('Failed', Pal.brick, Pal.brickBg, CupertinoIcons.xmark_circle),
      BatchItemStatus.confirmed => ('Confirmed', Pal.green, Pal.greenBg, CupertinoIcons.checkmark_seal_fill),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: isPdf(item.filePath)
                        ? Container(
                            color: Pal.brick.withValues(alpha: 0.15),
                            child: const Icon(CupertinoIcons.doc_fill, color: Pal.brick, size: 22),
                          )
                        : Image.file(
                            File(item.filePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(CupertinoIcons.doc),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [seller, dateStr].where((s) => s.toString().isNotEmpty).join(' · '),
                        style: const TextStyle(color: Pal.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.error != null) ...[
              const SizedBox(height: 8),
              Text(
                item.error!,
                style: const TextStyle(color: Pal.brick, fontSize: 11),
              ),
            ],
            if (item.status == BatchItemStatus.readyToReview || item.status == BatchItemStatus.needsAttention) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: Pal.muted,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onReview,
                    style: FilledButton.styleFrom(
                      backgroundColor: Pal.blue,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Review & Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
