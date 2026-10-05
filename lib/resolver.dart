import 'models.dart';

/// Category keywords -> (category, default months).
const _categories = <String, (String, int)>{
  'iphone': ('Phone', 12), 'phone': ('Phone', 12), 'mobile': ('Phone', 12),
  'tv': ('TV', 12), 'television': ('TV', 12),
  'ac': ('Air conditioner', 12), 'air conditioner': ('Air conditioner', 12),
  'laptop': ('Laptop', 12), 'notebook': ('Laptop', 12),
  'refrigerator': ('Refrigerator', 12), 'fridge': ('Refrigerator', 12),
  'washing': ('Washing machine', 24), 'mixer': ('Kitchen appliance', 12),
  'microwave': ('Kitchen appliance', 12), 'oven': ('Kitchen appliance', 12),
  'headphone': ('Audio', 12), 'earbuds': ('Audio', 12), 'speaker': ('Audio', 12),
  'watch': ('Wearable', 12),
};

/// Small curated brand+category table. ponytail: tiny seed list; grow it or
/// back it with a server table plus cached AI lookup (PRD section 7).
const _brandPolicy = <String, int>{
  'apple|Phone': 12, 'samsung|Phone': 12, 'samsung|TV': 12,
  'lg|Washing machine': 24, 'lg|TV': 12, 'sony|TV': 12, 'apple|Laptop': 12,
};

String guessCategory(String name) {
  final n = name.toLowerCase();
  for (final e in _categories.entries) {
    if (RegExp('\\b${RegExp.escape(e.key)}\\b').hasMatch(n)) return e.value.$1;
  }
  return 'Other';
}

/// Parses "1 year comprehensive", "24 months", "5 yr on compressor".
List<Term> parsePrinted(String? text) {
  if (text == null || text.trim().isEmpty) return [];
  final out = <Term>[];
  final re = RegExp(r'(\d+)\s*(years?|yrs?|months?|mos?)\b([^,;\n]*)',
      caseSensitive: false);
  for (final m in re.allMatches(text)) {
    final n = int.parse(m[1]!);
    final months = m[2]!.toLowerCase().startsWith('y') ? n * 12 : n;
    final rest = m[3]!.replaceAll(RegExp(r'^\s*(on|for)?\s*'), '').trim();
    out.add(Term(
        rest.isEmpty || rest.toLowerCase() == 'comprehensive'
            ? 'Product'
            : rest[0].toUpperCase() + rest.substring(1),
        months,
        TermSource.bill));
  }
  return out;
}

/// Order from the PRD: bill -> AI brand lookup -> brand+model policy -> category default -> manual.
List<Term> resolveWarranty(
    {required String name,
    required String brand,
    required String category,
    String? printed,
    List<Term>? aiTerms}) {
  final fromBill = parsePrinted(printed);
  if (fromBill.isNotEmpty) return fromBill;
  if (aiTerms != null && aiTerms.isNotEmpty) return aiTerms;
  final brandMonths = _brandPolicy['${brand.toLowerCase()}|$category'];
  if (brandMonths != null) return [Term('Product', brandMonths, TermSource.brand)];
  for (final e in _categories.values) {
    if (e.$1 == category) return [Term('Product', e.$2, TermSource.estimated)];
  }
  return [];
}

/// Validation rules from PRD section 7. Returns a message or null.
String? validateDate(DateTime d) {
  final now = DateTime.now();
  if (d.isAfter(now)) return 'Purchase date is in the future';
  if (d.isBefore(DateTime(now.year - 10, now.month, now.day))) {
    return 'Purchase date is older than 10 years';
  }
  return null;
}
