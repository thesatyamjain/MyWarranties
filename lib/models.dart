enum WStatus { active, expiringSoon, expired }

enum TermSource { bill, brand, estimated, manual }

const sourceLabel = {
  TermSource.bill: 'From bill',
  TermSource.brand: 'Brand policy',
  TermSource.estimated: 'Estimated',
  TermSource.manual: 'Entered by you',
};

DateTime addMonths(DateTime d, int months) {
  final t = d.year * 12 + d.month - 1 + months;
  final y = t ~/ 12, m = t % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day);
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class Term {
  String label;
  int months;
  TermSource source;
  Term(this.label, this.months, this.source);

  Map<String, dynamic> toJson() => {'l': label, 'm': months, 's': source.name};
  factory Term.fromJson(Map<String, dynamic> j) => Term(
      j['l'], j['m'], TermSource.values.byName(j['s']));
}

class Bill {
  final String id;
  String imagePath, seller, invoiceNo, currency;
  DateTime purchaseDate;
  double total;
  Bill(this.id, this.imagePath, this.seller, this.invoiceNo, this.purchaseDate,
      this.total, this.currency);

  Map<String, dynamic> toJson() => {
        'id': id,
        'img': imagePath,
        'seller': seller,
        'inv': invoiceNo,
        'date': purchaseDate.toIso8601String(),
        'total': total,
        'cur': currency,
      };
  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
      j['id'], j['img'], j['seller'], j['inv'], DateTime.parse(j['date']),
      (j['total'] as num).toDouble(), j['cur']);
}

/// One product on a bill, plus its warranty terms.
class Item {
  final String id, billId;
  String name, brand, model, serial, category;
  double price;
  DateTime start;
  List<Term> terms;
  Item(this.id, this.billId, this.name, this.brand, this.model, this.serial,
      this.category, this.price, this.start, this.terms,
      {this.basis = 'Purchase date',
      this.claimStatus = 'None',
      this.claimRef = '',
      this.claimNotes = ''});

  /// What `start` means: purchase / delivery / installation date (FR-14).
  String basis;

  /// FR-25 claim tracker: None, Filed, In progress, Resolved, Rejected.
  String claimStatus, claimRef, claimNotes;

  DateTime endOf(Term t) => addMonths(start, t.months);

  /// Latest end across all terms (warranty is "live" while any term is).
  DateTime? get endDate => terms.isEmpty
      ? null
      : terms.map(endOf).reduce((a, b) => a.isAfter(b) ? a : b);

  int get daysLeft => endDate == null
      ? 0
      : endDate!.difference(dayOnly(DateTime.now())).inDays;

  WStatus get status => daysLeft < 0
      ? WStatus.expired
      : daysLeft <= 30
          ? WStatus.expiringSoon
          : WStatus.active;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bill': billId,
        'name': name,
        'brand': brand,
        'model': model,
        'serial': serial,
        'cat': category,
        'price': price,
        'start': start.toIso8601String(),
        'terms': terms.map((t) => t.toJson()).toList(),
        'basis': basis,
        'cs': claimStatus,
        'cr': claimRef,
        'cn': claimNotes,
      };
  factory Item.fromJson(Map<String, dynamic> j) => Item(
      j['id'], j['bill'], j['name'], j['brand'], j['model'], j['serial'],
      j['cat'], (j['price'] as num).toDouble(), DateTime.parse(j['start']),
      [for (final t in j['terms']) Term.fromJson(t)],
      basis: j['basis'] ?? 'Purchase date',
      claimStatus: j['cs'] ?? 'None',
      claimRef: j['cr'] ?? '',
      claimNotes: j['cn'] ?? '');
}

bool isPdf(String path) => path.toLowerCase().endsWith('.pdf');

String countdown(int days) {
  if (days < 0) return 'Expired ${-days} d ago';
  if (days == 0) return 'Expires today';
  if (days < 60) return '$days d left';
  final m = days ~/ 30;
  final d = days % 30;
  return d == 0 ? '$m mo left' : '$m mo $d d left';
}
