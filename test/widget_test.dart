import 'package:flutter_test/flutter_test.dart';
import 'package:my_warranties/drive_sync.dart';
import 'package:my_warranties/models.dart';
import 'package:my_warranties/resolver.dart';
import 'package:my_warranties/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('month math clamps to month end', () {
    expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(addMonths(DateTime(2026, 9, 14), 12), DateTime(2027, 9, 14));
  });

  test('printed warranty parses multiple terms', () {
    final t = parsePrinted('1 year comprehensive, 5 years on compressor');
    expect(t.map((e) => e.months), [12, 60]);
    expect(t.last.label, 'Compressor');
    expect(t.every((e) => e.source == TermSource.bill), true);
  });

  test('resolver order: bill > brand > empty for AI search', () {
    expect(resolveWarranty(name: 'x', brand: 'LG', category: 'Washing machine', printed: '6 months').first.months, 6);
    expect(resolveWarranty(name: 'x', brand: 'LG', category: 'Washing machine').first.source, TermSource.brand);
    expect(resolveWarranty(name: 'x', brand: 'Acme', category: 'TV'), isEmpty);
    expect(resolveWarranty(name: 'x', brand: 'Acme', category: 'Other'), isEmpty);
  });

  test('status thresholds', () {
    Item at(int daysLeft) {
      final targetEnd = dayOnly(DateTime.now()).add(Duration(days: daysLeft));
      final start = DateTime(targetEnd.year - 1, targetEnd.month, targetEnd.day);
      return Item('i', 'b', 'n', '', '', '', 'Other', 0, start, [Term('P', 12, TermSource.bill)]);
    }
    expect(at(90).status, WStatus.active);
    expect(at(30).status, WStatus.expiringSoon);
    expect(at(-5).status, WStatus.expired);

    expect(countdown(-5), 'Expired');
    expect(countdown(-1584), 'Expired');
    expect(countdown(0), 'Expires today');
    expect(countdown(15), '15 d left');
    expect(countdown(790), '2 yr 2 mo left');

    expect(expiredRelative(-1), 'Expired yesterday');
    expect(expiredRelative(-15), 'Expired 15 d ago');
    expect(expiredRelative(-76), 'Expired 2 mo ago');
    expect(expiredRelative(-1584), 'Expired 4 yr 4 mo ago');
  });

  test('products without explicit terms start empty for AI search, not hardcoded presets', () {
    final terms = resolveWarranty(name: 'Custom Product', brand: 'Generic', category: 'Other');
    expect(terms, isEmpty);
  });

  test('TermSource.aiSearch replaces estimated with AI search label', () {
    final aiTerm = Term('Comprehensive', 12, TermSource.aiSearch);
    expect(sourceLabel[aiTerm.source], 'AI Search');

    // Backward compatibility: legacy 'estimated' in stored DB json maps to aiSearch
    final migrated = Term.fromJson({'l': 'Comprehensive', 'm': 12, 's': 'estimated'});
    expect(migrated.source, TermSource.aiSearch);
    expect(sourceLabel[migrated.source], 'AI Search');
  });

  test('drive auto sync pref toggling and state', () async {
    SharedPreferences.setMockInitialValues({'drive_auto_sync_enabled': true});
    await DriveSyncService.initPrefs();
    expect(DriveSyncService.isAutoSyncEnabled, isTrue);

    await DriveSyncService.setAutoSyncEnabled(false);
    expect(DriveSyncService.isAutoSyncEnabled, isFalse);
  });

  test('item soft delete, restore, and permanent deletion flow', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.load();

    final bill = Bill('b1', 'test_bill.jpg', 'Amazon', 'INV-100', DateTime(2026, 1, 1), 500, 'INR');
    final item = Item('i1', 'b1', 'Sony Headphones', 'Sony', 'WH-1000XM5', '', 'Electronics', 25000, DateTime(2026, 1, 1), [Term('Standard', 12, TermSource.bill)]);

    await store.add(bill, [item]);
    expect(store.activeItems.length, 1);
    expect(store.trashedItems.length, 0);

    // 1. Soft delete -> goes to Recycle Bin
    await store.moveToTrash(item);
    expect(store.activeItems.length, 0);
    expect(store.trashedItems.length, 1);
    expect(item.deletedAt, isNotNull);

    // 2. Restore -> returns to active list
    await store.restoreFromTrash(item);
    expect(store.activeItems.length, 1);
    expect(store.trashedItems.length, 0);
    expect(item.deletedAt, isNull);

    // 3. Move to trash and permanently delete
    await store.moveToTrash(item);
    expect(store.trashedItems.length, 1);
    await store.permanentlyDelete(item);
    expect(store.items.length, 0);
    expect(store.trashedItems.length, 0);
  });

  test('30-day auto-purge removes expired trash items', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store();
    await store.load();

    final bill = Bill('b2', 'test2.jpg', 'Flipkart', 'INV-200', DateTime(2025, 1, 1), 1000, 'INR');
    // Item trashed 35 days ago (should be purged)
    final oldItem = Item('iOld', 'b2', 'Old Case', 'Spigen', 'Rugged', '', 'Accessories', 500, DateTime(2025, 1, 1), [Term('Standard', 6, TermSource.bill)], deletedAt: DateTime.now().subtract(const Duration(days: 35)));
    // Item trashed 5 days ago (should NOT be purged)
    final recentItem = Item('iRecent', 'b2', 'New Charger', 'Apple', '20W', '', 'Accessories', 1900, DateTime(2026, 1, 1), [Term('Standard', 12, TermSource.bill)], deletedAt: DateTime.now().subtract(const Duration(days: 5)));

    store.bills.add(bill);
    store.items.addAll([oldItem, recentItem]);

    expect(store.trashedItems.length, 2);

    await store.autoPurgeOldTrash(retentionDays: 30);

    expect(store.trashedItems.length, 1);
    expect(store.trashedItems.first.id, 'iRecent');
  });

  test('recent warranties only includes non-expired active items', () {
    final now = DateTime.now();
    final expiredItem = Item('i1', 'b1', 'Old Phone', 'Samsung', '', '', 'Electronics', 10000, now.subtract(const Duration(days: 400)), [Term('Standard', 12, TermSource.bill)]);
    final activeItem = Item('i2', 'b1', 'New Laptop', 'Apple', '', '', 'Electronics', 80000, now.subtract(const Duration(days: 30)), [Term('Standard', 12, TermSource.bill)]);

    final all = [expiredItem, activeItem];
    final recent = all.where((i) => i.status != WStatus.expired).toList().reversed.take(4).toList();

    expect(recent.length, 1);
    expect(recent.first.id, 'i2');
    expect(recent.any((i) => i.id == 'i1'), false);
  });
}
