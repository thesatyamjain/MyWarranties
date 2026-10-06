import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Apple Liquid Glass Recycle Bin Screen
class RecycleBinScreen extends StatelessWidget {
  final Store store;
  const RecycleBinScreen(this.store, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final trashed = store.trashedItems;

    return DecoratedBox(
      decoration: glassBackdrop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Recycle Bin',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          actions: [
            if (trashed.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Pal.brick),
                icon: const Icon(CupertinoIcons.trash_slash, size: 18),
                label: const Text('Empty Bin', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Empty Recycle Bin?'),
                      content: Text(
                        'This will permanently delete all ${trashed.length} item(s) and their bills. This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Pal.brick),
                          child: const Text('Empty Permanently'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await store.emptyRecycleBin();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Recycle Bin emptied.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: trashed.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Pal.muted.withValues(alpha: 0.15),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(CupertinoIcons.trash, size: 32, color: Pal.muted),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Recycle Bin is Empty',
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleted warranties stay here so you can easily restore them if deleted by accident.',
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(color: Pal.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.info_circle_fill, size: 16, color: Colors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Items in the bin are automatically erased permanently after 30 days.',
                            style: t.bodySmall?.copyWith(
                              color: const Color(0xFF8A6200),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final item in trashed)
                    () {
                      final daysRemaining = item.deletedAt != null
                          ? 30 - DateTime.now().difference(item.deletedAt!).inDays
                          : 30;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LiquidGlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: t.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          [
                                            if (item.brand.isNotEmpty) item.brand,
                                            if (item.deletedAt != null)
                                              'Deleted ${DateFormat('dd MMM').format(item.deletedAt!)}',
                                          ].join(' · '),
                                          style: t.bodySmall?.copyWith(color: Pal.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: daysRemaining <= 5
                                          ? Pal.brick.withValues(alpha: 0.12)
                                          : Pal.paper,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      daysRemaining <= 1
                                          ? 'Purges today'
                                          : '$daysRemaining days left',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: daysRemaining <= 5 ? Pal.brick : Pal.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Pal.brick,
                                    side: BorderSide(color: Pal.brick.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(CupertinoIcons.delete, size: 14),
                                  label: const Text('Delete Permanently', style: TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete permanently?'),
                                        content: Text('"${item.name}" will be erased forever.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: TextButton.styleFrom(foregroundColor: Pal.brick),
                                            child: const Text('Delete Forever'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await store.permanentlyDelete(item);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('"${item.name}" permanently deleted.'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Pal.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                                  label: const Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  onPressed: () async {
                                    await store.restoreFromTrash(item);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Restored "${item.name}" to your active vault!'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }(),
                ],
              ),
      ),
    );
  }
}
