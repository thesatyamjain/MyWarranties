import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_flow.dart';
import 'detail_tools.dart';
import 'drive_sync.dart';
import 'extractor.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
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
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => MaterialApp(
            title: 'My Warranties',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            scrollBehavior: const MaterialScrollBehavior()
                .copyWith(physics: const BouncingScrollPhysics()),
            home: store.onboarded ? Shell(store) : Onboarding(store),
          ),
        ),
      );
}


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
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: store.finishOnboarding,
                  child: const Text('Get started'),
                ),
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
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 56,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Semantics(
                  button: true,
                  label: 'Add bill',
                  child: AppleBounce(
                    scaleFactor: 0.90,
                    onTap: () => startAddFlow(context, s),
                    child: const Glass(
                      radius: 22,
                      blur: 20,
                      showShadow: false,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(CupertinoIcons.plus, color: Pal.blue, size: 22),
                        ),
                      ),
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
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SizedBox(
                    height: 56,
                    child: Glass(
                      radius: 28,
                      padding: const EdgeInsets.all(4),
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
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.96),
                                        Colors.white.withValues(alpha: 0.76),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.90),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Pal.blue.withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
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
                                            height: 48,
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
    final expired = s.items.where((i) => i.status == WStatus.expired).toList();
    final recent = s.items.reversed.take(4).toList();
    final next = live.firstOrNull;

    // Categories breakdown
    final catCounts = <String, int>{};
    for (final it in s.items) {
      if (it.category.isNotEmpty) {
        catCounts[it.category] = (catCounts[it.category] ?? 0) + 1;
      }
    }

    if (s.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.shield_lefthalf_fill, size: 36, color: Pal.blue),
            ),
            const SizedBox(height: 20),
            Text('Warranty Vault Empty', style: t.headlineSmall),
            const SizedBox(height: 8),
            Text('Snap a receipt or bill. We will automatically track its expiry and notify you.',
                textAlign: TextAlign.center, style: t.bodyMedium),
            const SizedBox(height: 28),
            AppleBounce(
              onTap: () => startAddFlow(context, s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Pal.blue,
                  borderRadius: BorderRadius.circular(Pal.r),
                  boxShadow: [
                    BoxShadow(
                      color: Pal.blue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Scan Your First Bill',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        // 1. Vault Header Card (Hero Apple Liquid Glass Prism)
        AppleBounce(
          scaleFactor: 0.98,
          onTap: onLibrary,
          child: Glass(
            radius: 22,
            blur: 28,
            padding: const EdgeInsets.all(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF064E3B).withValues(alpha: 0.92),
                const Color(0xFF042F2E).withValues(alpha: 0.82),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF6EE7B7).withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF064E3B).withValues(alpha: 0.28),
                blurRadius: 28,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.shield_fill, color: Color(0xFF6EE7B7), size: 17),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'WARRANTY VAULT',
                          style: TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${s.items.length} Total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  soon.isNotEmpty
                      ? '${soon.length} Expiring Soon'
                      : (live.isNotEmpty ? 'All Warranties Protected' : 'All Expired'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  next != null
                      ? 'Next: ${next.name} (${countdown(next.daysLeft)})'
                      : 'No active warranties right now.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Bento Quick Metrics Grid (2 columns Liquid Glass)
        Row(
          children: [
            Expanded(
              child: LiquidGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Pal.greenBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(CupertinoIcons.checkmark_shield_fill, color: Pal.green, size: 18),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Pal.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${live.length}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 2),
                    const Text('Active Coverages', style: TextStyle(color: Pal.muted, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LiquidGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: soon.isNotEmpty ? Pal.amberBg : (expired.isNotEmpty ? Pal.brickBg : Pal.greenBg),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            soon.isNotEmpty ? CupertinoIcons.clock_fill : (expired.isNotEmpty ? CupertinoIcons.archivebox_fill : CupertinoIcons.check_mark),
                            color: soon.isNotEmpty ? Pal.amber : (expired.isNotEmpty ? Pal.brick : Pal.green),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      soon.isNotEmpty ? '${soon.length}' : (expired.isNotEmpty ? '${expired.length}' : '0'),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      soon.isNotEmpty ? 'Within 30 Days' : (expired.isNotEmpty ? 'Expired Total' : 'Action Needed'),
                      style: const TextStyle(color: Pal.muted, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 3. Category Distribution Bar (if categories exist)
        if (catCounts.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Categories in Vault', style: t.titleSmall),
              Text('${catCounts.length} types', style: const TextStyle(color: Pal.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in catCounts.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Glass(
                      radius: 12,
                      blur: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _categoryIcon(entry.key),
                            size: 14,
                            color: Pal.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Pal.paper,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Pal.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // 4. Urgent Expirations Section (if any)
        if (soon.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Pal.amber, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Expiring Soon', style: t.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          for (final i in soon) ItemTile(s, i),
        ],

        // 5. Recently Added Feed
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Warranties', style: t.titleSmall),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              onPressed: onLibrary,
              child: const Row(
                children: [
                  Text('See all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(width: 2),
                  Icon(CupertinoIcons.chevron_right, size: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final i in recent) ItemTile(s, i),
      ],
    );
  }

  static IconData _categoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('elect') || lower.contains('phone') || lower.contains('laptop') || lower.contains('audio') || lower.contains('headphone')) {
      return CupertinoIcons.device_phone_portrait;
    }
    if (lower.contains('appliance') || lower.contains('fridge') || lower.contains('tv') || lower.contains('ac')) {
      return CupertinoIcons.tv;
    }
    if (lower.contains('power') || lower.contains('battery')) {
      return CupertinoIcons.bolt_fill;
    }
    if (lower.contains('watch') || lower.contains('wear')) {
      return CupertinoIcons.stopwatch;
    }
    if (lower.contains('vehicle') || lower.contains('auto') || lower.contains('car')) {
      return CupertinoIcons.car_detailed;
    }
    return CupertinoIcons.cube_box_fill;
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
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Pal.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Home._categoryIcon(i.category),
                    color: Pal.blue,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                      [i.brand, 'Ends ${s.formatDate(i.endDate!)}']
                          .where((e) => e.isNotEmpty)
                          .join('  ·  '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Pal.muted)),
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
      Glass(
        radius: 14,
        blur: 20,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(
            fillColor: Colors.transparent,
            hintText: 'Search product, brand or model',
            prefixIcon: Icon(CupertinoIcons.search, color: Pal.blue),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
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
    return DecoratedBox(
      decoration: glassBackdrop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
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
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
          Text(i.name, style: t.headlineSmall),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: StatusPill(i)),
          const SizedBox(height: 20),
          LiquidGlassCard(
            padding: const EdgeInsets.all(16),
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
                      Text('Ends ${s.formatDate(i.endOf(term))}', style: t.bodySmall),
                    ]),
                  ),
                  SourceChip(term.source),
                ]),
              ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Starts ${s.formatDate(i.start)} (${i.basis.toLowerCase()}). ',
                    style: t.bodySmall),
                InkWell(
                  onTap: () => openWarrantyTerms(i),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Terms & conditions',
                          style: t.bodySmall?.copyWith(
                            color: Pal.blue,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Pal.blue,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(CupertinoIcons.arrow_up_right, size: 11, color: Pal.blue),
                      ],
                    ),
                  ),
                ),
                Text(' may apply.', style: t.bodySmall),
              ],
            ),
            Row(
              children: [
                TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                    onPressed: () => showStartSheet(context, s, i),
                    child: const Text('Change start date')),
                const SizedBox(width: 16),
                TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                    onPressed: () => recheckWarrantyPolicy(context, s, i),
                    icon: const Icon(CupertinoIcons.sparkles, size: 14),
                    label: const Text('AI Search Warranty')),
              ],
            ),
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
          kv('Purchase date', s.formatDate(bill.purchaseDate)),
        ],
        const SizedBox(height: 16),
        LiquidGlassCard(
          padding: EdgeInsets.zero,
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
                leading: const Icon(CupertinoIcons.doc_text, color: Pal.blue),
                title: const Text('Terms & conditions'),
                subtitle: Text('View official warranty rules for ${i.brand.isEmpty ? i.name : i.brand}'),
                trailing: const Icon(CupertinoIcons.arrow_up_right, size: 14, color: Pal.muted),
                onTap: () => openWarrantyTerms(i)),
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
        if (bill != null && isPdf(bill.imagePath)) ...[
          Text('Bill Document', style: t.titleSmall),
          const SizedBox(height: 8),
          LiquidGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Pal.brick.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(CupertinoIcons.doc_fill, color: Pal.brick, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.invoiceNo.isNotEmpty
                                ? 'Invoice #${bill.invoiceNo}'
                                : 'Purchase Invoice (PDF)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            bill.seller.isNotEmpty ? bill.seller : 'Official Receipt',
                            style: const TextStyle(color: Pal.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0x15000000)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppleBounce(
                        scaleFactor: 0.95,
                        onTap: () => openBillPdf(bill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Pal.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.eye_fill, size: 16, color: Pal.blue),
                              SizedBox(width: 6),
                              Text(
                                'Preview PDF',
                                style: TextStyle(
                                  color: Pal.blue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppleBounce(
                        scaleFactor: 0.95,
                        onTap: () => shareBillPdf(i, bill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.share, size: 16, color: Pal.ink),
                              SizedBox(width: 6),
                              Text(
                                'Share',
                                style: TextStyle(
                                  color: Pal.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
    ),
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
      Text('Notifications & Alerts', style: t.titleSmall),
      const SizedBox(height: 4),
      Text('Schedule automated local reminders before warranty periods elapse.',
          style: t.bodySmall),
      const SizedBox(height: 12),
      Glass(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Pal.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.bell_fill, color: Pal.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.offsets.isEmpty
                            ? 'Reminders muted'
                            : '${s.offsets.length} alert interval${s.offsets.length > 1 ? "s" : ""} scheduled',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Delivered daily at 9:00 AM on scheduled days',
                        style: TextStyle(color: Pal.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0x15000000)),
            const SizedBox(height: 14),
            Text(
              'ALERT WINDOWS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Pal.muted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final d in const [
                  (60, '60 days'),
                  (30, '30 days'),
                  (14, '14 days'),
                  (7, '7 days'),
                  (3, '3 days'),
                  (1, '1 day'),
                  (0, 'Expiry day'),
                ])
                  AppleBounce(
                    scaleFactor: 0.94,
                    onTap: () {
                      final has = s.offsets.contains(d.$1);
                      s.setOffsets(has
                          ? s.offsets.where((x) => x != d.$1).toList()
                          : [...s.offsets, d.$1]);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: s.offsets.contains(d.$1)
                            ? Pal.blue
                            : Colors.white.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: s.offsets.contains(d.$1)
                              ? Pal.blue
                              : Colors.white.withValues(alpha: 0.90),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: s.offsets.contains(d.$1)
                                ? Pal.blue.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.03),
                            blurRadius: s.offsets.contains(d.$1) ? 8 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.offsets.contains(d.$1)) ...[
                            const Icon(CupertinoIcons.checkmark_alt,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            d.$2,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: s.offsets.contains(d.$1)
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: s.offsets.contains(d.$1)
                                  ? Colors.white
                                  : Pal.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
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
      Text('Google Drive Cloud Sync', style: t.titleSmall),
      const SizedBox(height: 4),
      Text('Securely back up your bills and warranties to your own Google Drive storage.',
          style: t.bodySmall),
      const SizedBox(height: 12),
      _DriveSyncCard(s),
      const SizedBox(height: 28),
      Text('Device Backup', style: t.titleSmall),
      const SizedBox(height: 4),
      Text('Android Auto-Backup is enabled. Files also back up automatically when Android device backup is active.',
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
      const SizedBox(height: 36),
      const BuiltByFooter(),
    ]);
  }

  void _editApiKey(BuildContext context, Store s) {
    final controller = TextEditingController(text: s.userApiKey);
    showDialog(
      context: context,
      builder: (ctx) {
        bool testing = false;
        String? testResult;
        bool? testSuccess;

        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Gemini API Key'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your Google Gemini API key to enable AI bill parsing. Keys remain private on your device.',
                    style: TextStyle(fontSize: 13),
                  ),
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
                  const SizedBox(height: 10),
                  // Test Key Action
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: testing
                            ? null
                            : () async {
                                final text = controller.text.trim();
                                if (text.isEmpty) {
                                  setState(() {
                                    testResult = 'Please enter a key first.';
                                    testSuccess = false;
                                  });
                                  return;
                                }
                                setState(() {
                                  testing = true;
                                  testResult = null;
                                  testSuccess = null;
                                });
                                final res = await testApiKey(text);
                                setState(() {
                                  testing = false;
                                  testResult = res.message;
                                  testSuccess = res.ok;
                                });
                              },
                        icon: testing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(CupertinoIcons.checkmark_shield, size: 16),
                        label: Text(testing ? 'Testing...' : 'Test Key'),
                      ),
                    ],
                  ),
                  if (testResult != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: testSuccess == true
                            ? Pal.green.withValues(alpha: 0.12)
                            : Pal.brick.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            testSuccess == true
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.exclamationmark_circle_fill,
                            size: 16,
                            color: testSuccess == true ? Pal.green : Pal.brick,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testResult!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: testSuccess == true ? Pal.green : Pal.brick,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                  await s.setApiKey(controller.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BuiltByFooter extends StatelessWidget {
  const BuiltByFooter({super.key});

  static const _url = 'https://thesoftwareco.pages.dev';

  Future<void> _launch() async {
    final uri = Uri.parse(_url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => _showTermsDialog(context),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    fontSize: 12,
                    color: Pal.muted,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const Text('·', style: TextStyle(color: Pal.muted, fontSize: 14)),
            InkWell(
              onTap: () => _showPrivacyDialog(context),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Pal.muted,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: AppleBounce(
            onTap: _launch,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Built by ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Pal.muted.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Text(
                    'The Software Labs',
                    style: TextStyle(
                      fontSize: 12,
                      color: Pal.blue,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Pal.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.arrow_up_right,
                    size: 11,
                    color: Pal.blue.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Personal Utility:\nMy Warranties is designed to assist you in tracking purchase receipts, bills, and manufacturer warranty periods. All product warranties are granted and governed exclusively by their respective original manufacturers or retailers.\n\n'
            '2. Information Accuracy:\nWarranty dates, policies, and AI extractions are offered as organizational estimates. Users are advised to preserve their original purchase invoices for formal warranty claims.\n\n'
            '3. Data Privacy & Storage:\nAll receipts and documents reside locally on your device or in your personal Google Drive / Android Auto-Backup. No document is uploaded to third-party commercial databases.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Zero Telemetry & Privacy First:\nMy Warranties does not track, collect, sell, or rent your personal data, invoices, or device details.\n\n'
            '2. Storage & Cloud Sync:\nBills, warranty details, and PDFs are stored locally in your device storage. When Google Drive Sync is enabled, files are transferred directly to your own Google Drive.\n\n'
            '3. AI Bill Scanning:\nWhen scanning receipts with Gemini AI, bill images are processed strictly to extract warranty details.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DriveSyncCard extends StatefulWidget {
  final Store store;
  const _DriveSyncCard(this.store);

  @override
  State<_DriveSyncCard> createState() => _DriveSyncCardState();
}

class _DriveSyncCardState extends State<_DriveSyncCard> {
  bool _busy = false;
  String? _statusMessage;
  bool? _statusOk;

  Future<void> _handleSignIn() async {
    setState(() => _busy = true);
    try {
      await DriveSyncService.signIn();
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        setState(() {
          _statusMessage = 'Sign-In error: $errText';
          _statusOk = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _busy = true);
    await DriveSyncService.signOut();
    if (mounted) {
      setState(() {
        _busy = false;
        _statusMessage = null;
        _statusOk = null;
      });
    }
  }

  Future<void> _handleBackup() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    final res = await DriveSyncService.backup(widget.store);
    if (mounted) {
      setState(() {
        _busy = false;
        _statusMessage = res.message;
        _statusOk = res.ok;
      });
    }
  }

  Future<void> _handleRestore() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Drive?'),
        content: const Text(
          'This will download and merge bills from your Google Drive into your local library.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (proceed != true) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    final res = await DriveSyncService.restore(widget.store);
    if (mounted) {
      setState(() {
        _busy = false;
        _statusMessage = res.message;
        _statusOk = res.ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = DriveSyncService.currentUser;

    return Glass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Pal.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.cloud_upload_fill, color: Pal.blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user != null ? (user.displayName ?? 'Google Connected') : 'Google Account',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user != null ? user.email : 'Sign in to sync bills & PDFs',
                      style: const TextStyle(color: Pal.muted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (user == null)
                AppleBounce(
                  onTap: _busy ? null : _handleSignIn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Pal.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(CupertinoIcons.square_arrow_right, size: 18, color: Pal.muted),
                  tooltip: 'Sign Out',
                  onPressed: _busy ? null : _handleSignOut,
                ),
            ],
          ),
          if (user != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0x15000000)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppleBounce(
                    onTap: _busy ? null : _handleBackup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Pal.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.arrow_up_circle_fill, size: 16, color: Pal.blue),
                          const SizedBox(width: 6),
                          Text(
                            _busy ? 'Syncing...' : 'Backup to Drive',
                            style: const TextStyle(
                              color: Pal.blue,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppleBounce(
                    onTap: _busy ? null : _handleRestore,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.arrow_down_circle_fill, size: 16, color: Pal.ink),
                          SizedBox(width: 6),
                          Text(
                            'Restore',
                            style: TextStyle(
                              color: Pal.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _statusOk == true
                    ? Pal.green.withValues(alpha: 0.12)
                    : Pal.brick.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusOk == true
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.exclamationmark_circle_fill,
                    size: 15,
                    color: _statusOk == true ? Pal.green : Pal.brick,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusOk == true ? Pal.green : Pal.brick,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
