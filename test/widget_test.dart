import 'package:flutter_test/flutter_test.dart';
import 'package:my_warranties/models.dart';
import 'package:my_warranties/resolver.dart';

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

  test('resolver order: bill > brand > estimate > none', () {
    expect(resolveWarranty(name: 'x', brand: 'LG', category: 'Washing machine', printed: '6 months').first.months, 6);
    expect(resolveWarranty(name: 'x', brand: 'LG', category: 'Washing machine').first.source, TermSource.brand);
    expect(resolveWarranty(name: 'x', brand: 'Acme', category: 'TV').first.source, TermSource.estimated);
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
}
