import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'add_flow.dart';
import 'detail_tools.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  try {
    await store.load();
  } catch (e, st) {
    debugPrint('Store load error: $e\n$st');
  }
  runApp(App(store));
}

class App extends StatelessWidget {
  final Store store;
  const App(this.store, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'My Warranties',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          scrollBehavior: const MaterialScrollBehavior()
              .copyWith(physics: const BouncingScrollPhysics()),
          home: store.onboarded ? Shell(store) : Onboarding(store),
        ),
      );
}

final _date = DateFormat('d MMM yyyy');

// ---------- 1. Onboarding ----------
class Onboarding extends StatelessWidget {
  final Store store;
  const Onboarding(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(),
            Text('Know when every\nwarranty ends.', style: t.headlineMedium?.copyWith(fontSize: 38)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                  'Snap a bill. We read the product and date, find the warranty, and remind you before it runs out. The bill is one tap away when something breaks.',
                  style: t.bodyMedium),
            ),
            const Spacer(flex: 2),
            AppleBounce(
              scaleFactor: 0.97,
              onTap: store.finishOnboarding,
              child: const SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: null, child: Text('Get started')),
              ),
            ),
            const SizedBox(height: 10),
            Center(child: Text('Your bills stay on this phone for now.', style: t.bodySmall)),
          ]),
        ),
      ),
    );
  }
}

// ---------- Shell ----------
class Shell extends StatefulWidget {
  final Store store;
  const Shell(this.store, {super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Container(
        decoration: glassBackdrop,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            toolbarHeight: 52,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Semantics(
                  button: true,
                  label: 'Add bill',
                  child: AppleBounce(
                    scaleFactor: 0.90,
                    onTap: () => startAddFlow(context, s),
                    child: const Glass(
                      radius: 20,
                      child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(CupertinoIcons.add, color: Pal.blue, size: 22)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
              bottom: false,
              child: [
            Home(s, onLibrary: () => setState(() => tab = 1)),
            Library(s),
            SettingsScreen(s),
          ][tab]),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 12),
              child: Glass(
                radius: 32,
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const count = 3;
                    final itemWidth = constraints.maxWidth / count;
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Gliding indicator pill
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment(-1.0 + (tab / (count - 1)) * 2.0, 0.0),
                          child: Container(
                            width: itemWidth,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              color: Colors.white.withValues(alpha: 0.85),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Tabs row
                        Row(
                          children: [
                            for (final (i, d) in const [
                              (CupertinoIcons.house, 'Home'),
                              (CupertinoIcons.archivebox, 'Library'),
                              (CupertinoIcons.gear, 'Settings'),
                            ].indexed)
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: tab == i,
                                  label: d.$2,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => setState(() => tab = i),
                                    child: SizedBox(
                                      height: 44,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            d.$1,
                                            size: 20,
                                            color: tab == i ? Pal.blue : Pal.muted,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            d.$2,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: tab == i ? Pal.blue : Pal.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- 2. Home ----------
class Home extends StatelessWidget {
  final Store s;
  final VoidCallback onLibrary;
  const Home(this.s, {super.key, required this.onLibrary});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final live = s.items.where((i) => i.status != WStatus.expired).toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    final soon = live.where((i) => i.status == WStatus.expiringSoon).toList();
    final recent = s.items.reversed.take(3).toList();
    if (s.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(CupertinoIcons.doc_text, size: 48, color: Pal.muted),
            const SizedBox(height: 16),
            Text('No warranties yet', style: t.headlineSmall),
            const SizedBox(height: 6),
            Text('Add your first bill. It takes about 30 seconds.',
                textAlign: TextAlign.center, style: t.bodyMedium),
          ]),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 96), children: [
      Text('${live.length} active', style: t.headlineMedium?.copyWith(fontSize: 34)),
      Text(soon.isEmpty ? 'Nothing expires in the next 30 days.' : '${soon.length} expiring within 30 days.',
          style: t.bodyMedium),
      const SizedBox(height: 28),
      if (soon.isNotEmpty) ...[
        Text('Expiring soon', style: t.titleMedium),
        const SizedBox(height: 10),
        for (final i in soon) ItemTile(s, i),
        const SizedBox(height: 20),
      ],
      Text('Recently added', style: t.titleMedium),
      const SizedBox(height: 10),
      for (final i in recent) ItemTile(s, i),
      TextButton(onPressed: onLibrary, child: const Text('See all in library')),
    ]);
  }
}

class StatusPill extends StatelessWidget {
  final Item i;
  const StatusPill(this.i, {super.key});
  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (i.status) {
      WStatus.active => (Pal.green, Pal.greenBg),
      WStatus.expiringSoon => (Pal.amber, Pal.amberBg),
      WStatus.expired => (Pal.brick, Pal.brickBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(countdown(i.daysLeft),
          style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class ItemTile extends StatelessWidget {
  final Store s;
  final Item i;
  const ItemTile(this.s, this.i, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppleBounce(
          scaleFactor: 0.97,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => Detail(s, i))),
          child: Container(
            decoration: cardDecoration,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                      [i.brand, 'Ends ${_date.format(i.endDate!)}']
                          .where((e) => e.isNotEmpty)
                          .join('  ·  '),
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              const SizedBox(width: 10),
              StatusPill(i),
            ]),
          ),
        ),
      );
}

// ---------- 6. Library ----------
class Library extends StatefulWidget {
  final Store s;
  const Library(this.s, {super.key});
  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> {
  String q = '';
  WStatus? status;
  String? category, brand;
  bool newestFirst = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final all = widget.s.items;
    final cats = {for (final i in all) i.category}.toList()..sort();
    final brands = {for (final i in all) if (i.brand.isNotEmpty) i.brand}.toList()..sort();
    final list = all.where((i) {
      final hay = '${i.name} ${i.brand} ${i.model}'.toLowerCase();
      return hay.contains(q.toLowerCase()) &&
          (status == null || i.status == status) &&
          (category == null || i.category == category) &&
          (brand == null || i.brand == brand);
    }).toList()
      ..sort((a, b) => newestFirst
          ? b.start.compareTo(a.start)
          : a.daysLeft.compareTo(b.daysLeft)); // default: soonest expiry first
    Widget chip(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(label: Text(label), selected: on, onSelected: (_) => tap()),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 96), children: [
      Text('Library', style: t.headlineMedium?.copyWith(fontSize: 34)),
      const SizedBox(height: 14),
      TextField(
        onChanged: (v) => setState(() => q = v),
        decoration: const InputDecoration(
            hintText: 'Search product, brand or model', prefixIcon: Icon(CupertinoIcons.search)),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final st in WStatus.values)
            chip(const {
              WStatus.active: 'Active',
              WStatus.expiringSoon: 'Expiring soon',
              WStatus.expired: 'Expired'
            }[st]!, status == st, () => setState(() => status = status == st ? null : st)),
          for (final c in cats)
            chip(c, category == c, () => setState(() => category = category == c ? null : c)),
          for (final b in brands)
            chip(b, brand == b, () => setState(() => brand = brand == b ? null : b)),
        ]),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
            onPressed: () => setState(() => newestFirst = !newestFirst),
            icon: const Icon(CupertinoIcons.arrow_up_arrow_down, size: 18),
            label: Text(newestFirst ? 'Newest first' : 'Expiring first')),
      ),
      if (list.isEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
                child: Text(all.isEmpty ? 'Your library is empty.' : 'Nothing matches these filters.',
                    style: t.bodyMedium)))
      else
        for (final i in list) ItemTile(widget.s, i),
    ]);
  }
}

// ---------- 7. Product detail ----------
class Detail extends StatelessWidget {
  final Store s;
  final Item i;
  const Detail(this.s, this.i, {super.key});
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: s, builder: (context, _) => _body(context));

  Widget _body(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bill = s.billOf(i);
    Widget kv(String k, String v) => v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text(k, style: t.bodyMedium)),
              Expanded(child: Text(v)),
            ]),
          );
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
            tooltip: 'Delete',
            icon: const Icon(CupertinoIcons.delete),
            onPressed: () async {
              final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                        title: const Text('Delete this warranty?'),
                        content: const Text('The bill image is removed too if no other product uses it.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ));
              if (ok == true) {
                await s.remove(i);
                if (context.mounted) Navigator.pop(context);
              }
            }),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        Text(i.name, style: t.headlineSmall),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: StatusPill(i)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Warranty terms', style: t.titleSmall),
            const SizedBox(height: 8),
            for (final term in i.terms)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${term.label}: ${term.months >= 12 && term.months % 12 == 0 ? '${term.months ~/ 12} yr' : '${term.months} mo'}'),
                      Text('Ends ${_date.format(i.endOf(term))}', style: t.bodySmall),
                    ]),
                  ),
                  SourceChip(term.source),
                ]),
              ),
            const SizedBox(height: 6),
            Text('Starts ${_date.format(i.start)} (${i.basis.toLowerCase()}). Terms and conditions may apply.',
                style: t.bodySmall),
            TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                onPressed: () => showStartSheet(context, s, i),
                child: const Text('Change start date')),
          ]),
        ),
        const SizedBox(height: 20),
        kv('Brand', i.brand),
        kv('Model', i.model),
        kv('Serial / IMEI', i.serial),
        kv('Category', i.category),
        kv('Price', i.price > 0 ? 'INR ${i.price.toStringAsFixed(0)}' : ''),
        if (bill != null) ...[
          kv('Seller', bill.seller),
          kv('Invoice', bill.invoiceNo),
        ],
        const SizedBox(height: 16),
        Container(
          decoration: cardDecoration,
          child: Column(children: [
            if (bill != null)
              ListTile(
                  leading: const Icon(CupertinoIcons.share, color: Pal.blue),
                  title: const Text('Share bill as PDF'),
                  subtitle: const Text('Send it to the brand or service centre'),
                  onTap: () => shareBillPdf(i, bill)),
            ListTile(
                leading: const Icon(CupertinoIcons.phone, color: Pal.blue),
                title: const Text('Find brand support'),
                subtitle: Text('Customer care for ${i.brand.isEmpty ? 'this product' : i.brand}'),
                onTap: () => openSupport(i)),
            ListTile(
                leading: const Icon(CupertinoIcons.calendar_badge_plus, color: Pal.blue),
                title: const Text('Add expiry to calendar'),
                onTap: () => shareCalendarEvent(i)),
            ListTile(
                leading: const Icon(CupertinoIcons.doc_checkmark, color: Pal.blue),
                title: const Text('Claim tracker'),
                subtitle: Text(i.claimStatus == 'None'
                    ? 'No claim filed'
                    : '${i.claimStatus}${i.claimRef.isEmpty ? '' : '  ·  ${i.claimRef}'}'),
                onTap: () => showClaimSheet(context, s, i)),
          ]),
        ),
        const SizedBox(height: 16),
        if (bill != null && isPdf(bill.imagePath))
          Container(
            decoration: cardDecoration,
            child: ListTile(
                leading: const Icon(CupertinoIcons.doc_richtext, color: Pal.muted),
                title: const Text('Bill (PDF)'),
                subtitle: const Text('Tap to open or share'),
                onTap: () => shareBillPdf(i, bill)),
          ),
        if (bill != null && !isPdf(bill.imagePath)) ...[
          Text('Bill', style: t.titleSmall),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white),
                        body: Center(
                            child: InteractiveViewer(
                                maxScale: 5, child: Image.file(File(bill.imagePath))))))),
            child: Semantics(
              label: 'Bill image, tap to enlarge',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Pal.r),
                child: Image.file(File(bill.imagePath),
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(
                        height: 80, child: Center(child: Text('Bill image unavailable')))),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ---------- 8/9. Settings and reminders ----------
class SettingsScreen extends StatelessWidget {
  final Store s;
  const SettingsScreen(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 96), children: [
      Text('Settings', style: t.headlineMedium?.copyWith(fontSize: 34)),
      const SizedBox(height: 16),
      Text('Remind me before expiry', style: t.titleSmall),
      const SizedBox(height: 4),
      Text('Reminders arrive at 9:00 on the chosen day.', style: t.bodySmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final d in const [60, 30, 14, 7, 3, 1, 0])
          FilterChip(
            label: Text(d == 0 ? 'On expiry day' : d == 1 ? '1 day before' : '$d days before'),
            selected: s.offsets.contains(d),
            onSelected: (on) =>
                s.setOffsets(on ? [...s.offsets, d] : s.offsets.where((x) => x != d).toList()),
          ),
      ]),
      const SizedBox(height: 28),
      Text('Gemini AI Configuration', style: t.titleSmall),
      const SizedBox(height: 4),
      Text('Use your own Gemini API key for instant bill extraction and policy lookups.',
          style: t.bodySmall),
      const SizedBox(height: 12),
      Glass(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(
              s.userApiKey.isNotEmpty ? Icons.key : Icons.key_off_outlined,
              color: s.userApiKey.isNotEmpty ? Pal.green : Pal.muted,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  s.userApiKey.isNotEmpty
                      ? 'Custom API Key active (•••${s.userApiKey.length > 4 ? s.userApiKey.substring(s.userApiKey.length - 4) : ""})'
                      : 'No custom key configured',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  s.userApiKey.isNotEmpty
                      ? 'Saved securely on this device'
                      : 'Will fall back to build-time key if available',
                  style: const TextStyle(color: Pal.muted, fontSize: 12),
                ),
              ]),
            ),
            AppleBounce(
              onTap: () => _editApiKey(context, s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Pal.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  s.userApiKey.isNotEmpty ? 'Edit' : 'Add Key',
                  style: const TextStyle(
                      color: Pal.blue, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 28),
      Text('Backup and sync', style: t.titleSmall),
      const SizedBox(height: 4),
      // ponytail: cloud backup (FR-27) pending Firebase project config.
      Text('Cloud backup is not on yet. Your bills are stored on this phone only.',
          style: t.bodyMedium),
      const SizedBox(height: 28),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
            foregroundColor: Pal.brick,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: Pal.brick),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Pal.r))),
        onPressed: () async {
          final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                    title: const Text('Delete all data?'),
                    content: const Text('Every bill, image and warranty on this phone is erased. This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete everything')),
                    ],
                  ));
          if (ok == true) await s.deleteAll();
        },
        child: const Text('Delete all my data'),
      ),
    ]);
  }

  void _editApiKey(BuildContext context, Store s) {
    final controller = TextEditingController(text: s.userApiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Enter your Google Gemini API key. It will be kept securely on your device for AI bill recognition.'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'AIzaSy...',
              border: OutlineInputBorder(),
              labelText: 'API Key',
            ),
          ),
        ]),
        actions: [
          if (s.userApiKey.isNotEmpty)
            TextButton(
              onPressed: () async {
                await s.setApiKey('');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await s.setApiKey(controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

