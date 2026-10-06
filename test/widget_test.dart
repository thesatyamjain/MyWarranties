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
  });

  test('products without explicit terms start empty for AI search, not hardcoded presets', () {
    final terms = resolveWarranty(name: 'Custom Product', brand: 'Generic', category: 'Other');
    expect(terms, isEmpty);
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
}
