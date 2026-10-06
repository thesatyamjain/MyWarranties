import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'add_flow.dart';
import 'main.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Handles receiving shared images, PDFs, and `.mywarranty` card bundles from external apps
class ShareReceiver {
  static const _channel = MethodChannel('com.thesoftwarelabs.mywarranties/share');
  static bool _listening = false;

  /// Check if the app was launched by receiving shared file(s)
  static Future<List<String>> getInitialSharedFiles() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final List? files = await _channel.invokeMethod<List>('getInitialSharedFiles');
      return files?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      debugPrint('ShareReceiver getInitialSharedFiles error: $e');
      return [];
    }
  }

  /// Listen for incoming shared files while the app is active or launched
  static void initialize(BuildContext context, Store store) {
    if (kIsWeb || !Platform.isAndroid) return;

    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onFilesShared') {
          final List? files = call.arguments as List?;
          final paths = files?.map((e) => e.toString()).toList() ?? [];
          if (paths.isNotEmpty && context.mounted) {
            handleIncomingSharedFiles(context, store, paths);
          }
        }
      });
    }

    // Process any files that launched the app
    getInitialSharedFiles().then((paths) {
      if (paths.isNotEmpty && context.mounted) {
        handleIncomingSharedFiles(context, store, paths);
      }
    });
  }

  /// Route shared files:
  /// - If `.mywarranty`: prompt 1-click import into vault (item + countdown + embedded bill).
  /// - If image/PDF: route to ProcessingScreen for OCR / AI scanning.
  static void handleIncomingSharedFiles(BuildContext context, Store store, List<String> paths) {
    for (final p in paths) {
      final file = File(p);
      if (!file.existsSync()) continue;

      if (p.toLowerCase().endsWith('.mywarranty')) {
        _importMyWarrantyCard(context, store, file);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProcessingScreen(store: store, file: file),
          ),
        );
      }
    }
  }

  /// Parse and prompt 1-click import for a .mywarranty card bundle
  static Future<void> _importMyWarrantyCard(BuildContext context, Store store, File file) async {
    try {
      final content = await file.readAsString();
      final Map<String, dynamic> bundle = jsonDecode(content);

      if (!bundle.containsKey('item')) {
        throw const FormatException('Invalid .mywarranty bundle');
      }

      final itemJson = Map<String, dynamic>.from(bundle['item']);
      final billJson = bundle['bill'] != null ? Map<String, dynamic>.from(bundle['bill']) : null;
      final billData = bundle['bill_data'] as String?;
      final billExt = bundle['bill_ext'] as String? ?? 'jpg';

      // Generate fresh local IDs so they never collide with existing entries
      final newBillId = 'bill_${DateTime.now().millisecondsSinceEpoch}';
      final newItemId = 'item_${DateTime.now().millisecondsSinceEpoch}';

      Bill? importedBill;
      if (billJson != null) {
        String savedImagePath = '';
        if (billData != null && billData.isNotEmpty) {
          final bytes = base64Decode(billData);
          final docsDir = await getApplicationDocumentsDirectory();
          final billFile = File('${docsDir.path}/$newBillId.$billExt');
          await billFile.writeAsBytes(bytes, flush: true);
          savedImagePath = billFile.path;
        }

        importedBill = Bill(
          newBillId,
          savedImagePath,
          billJson['seller'] ?? '',
          billJson['inv'] ?? '',
          DateTime.tryParse(billJson['date'] ?? '') ?? DateTime.now(),
          (billJson['total'] as num?)?.toDouble() ?? 0.0,
          billJson['cur'] ?? 'INR',
        );
      }

      final importedItem = Item(
        newItemId,
        newBillId,
        itemJson['name'] ?? 'Imported Warranty',
        itemJson['brand'] ?? '',
        itemJson['model'] ?? '',
        itemJson['serial'] ?? '',
        itemJson['cat'] ?? 'General',
        (itemJson['price'] as num?)?.toDouble() ?? 0.0,
        DateTime.tryParse(itemJson['start'] ?? '') ?? DateTime.now(),
        [
          if (itemJson['terms'] != null)
            for (final t in itemJson['terms']) Term.fromJson(Map<String, dynamic>.from(t))
        ],
        basis: itemJson['basis'] ?? 'Purchase date',
        claimStatus: itemJson['cs'] ?? 'None',
        claimRef: itemJson['cr'] ?? '',
        claimNotes: itemJson['cn'] ?? '',
      );

      if (!context.mounted) return;

      // Show Apple Liquid Glass Import Modal
      final proceed = await showModalBottomSheet<bool>(
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
                    child: const Icon(CupertinoIcons.square_arrow_down_fill, color: Pal.blue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Warranty Card',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Direct .mywarranty 1-Click Import',
                          style: TextStyle(color: Pal.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LiquidGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            importedItem.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Pal.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            countdown(importedItem.daysLeft),
                            style: const TextStyle(
                              color: Pal.blue,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (importedItem.brand.isNotEmpty || importedItem.model.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        [importedItem.brand, importedItem.model].where((s) => s.isNotEmpty).join(' · '),
                        style: const TextStyle(color: Pal.muted, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0x15000000)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          importedBill?.imagePath.isNotEmpty == true
                              ? CupertinoIcons.doc_fill
                              : CupertinoIcons.doc,
                          size: 15,
                          color: Pal.ink,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          importedBill?.imagePath.isNotEmpty == true
                              ? 'Original bill attached'
                              : 'No bill image attached',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Pal.r)),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Pal.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Pal.r)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Add to Vault', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (proceed == true && context.mounted) {
        if (importedBill != null) {
          store.bills.add(importedBill);
        }
        store.items.add(importedItem);
        await store.update();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${importedItem.name}" to your vault'),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Open detail screen right away
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Detail(store, importedItem),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error importing .mywarranty: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open .mywarranty card: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

