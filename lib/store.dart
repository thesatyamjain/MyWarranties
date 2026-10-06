import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'drive_sync.dart';
import 'models.dart';
import 'widget_bridge.dart';

/// Local-first store. ponytail: JSON blob in SharedPreferences is fine for
/// hundreds of items; swap for Firestore/SQLite when cloud sync (FR-27) lands.
class Store extends ChangeNotifier {
  List<Bill> bills = [];
  List<Item> items = [];
  List<int> offsets = [30, 7, 0];
  bool onboarded = false;
  String userApiKey = '';
  late SharedPreferences _p;
  final _n = FlutterLocalNotificationsPlugin();

  /// Automatically formats dates according to standard DD/MM/YY convention
  String formatDate(DateTime d) => DateFormat('dd/MM/yy').format(d);


  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('data');
    if (raw != null) {
      final j = jsonDecode(raw);
      bills = [for (final b in j['bills']) Bill.fromJson(b)];
      items = [for (final i in j['items']) Item.fromJson(i)];
      offsets = List<int>.from(j['offsets'] ?? offsets);
    }
    onboarded = _p.getBool('onboarded') ?? false;
    userApiKey = _p.getString('gemini_api_key') ?? '';
    if (!kIsWeb) {
      _initNotifications();
    }
    await DriveSyncService.initPrefs();
    WidgetBridge.sync(this);
  }

  Future<void> setApiKey(String key) async {
    userApiKey = key.trim();
    if (userApiKey.isEmpty) {
      await _p.remove('gemini_api_key');
    } else {
      await _p.setString('gemini_api_key', userApiKey);
    }
    notifyListeners();
  }

  Future<void> _initNotifications() async {
    try {
      tz.initializeTimeZones();
      await _n.initialize(
          settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings()));
      await _n
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _reschedule();
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    await _p.setBool('onboarded', true);
    notifyListeners();
  }

  Future<File> saveImage(File src, String id) async {
    final dir = await getApplicationDocumentsDirectory();
    return src.copy('${dir.path}/$id${isPdf(src.path) ? '.pdf' : '.jpg'}');
  }

  Bill? billOf(Item i) => bills.where((b) => b.id == i.billId).firstOrNull;

  bool hasInvoice(String no) =>
      no.isNotEmpty && bills.any((b) => b.invoiceNo.toLowerCase() == no.toLowerCase());

  Future<void> add(Bill b, List<Item> its) async {
    bills.add(b);
    items.addAll(its);
    await _commit();
  }

  Future<void> update() => _commit();

  Future<void> remove(Item i) async {
    items.remove(i);
    final b = billOf(i);
    if (b != null && !items.any((x) => x.billId == b.id)) {
      bills.remove(b);
      try {
        File(b.imagePath).deleteSync();
      } catch (_) {}
    }
    await _commit();
  }

  Future<void> setOffsets(List<int> o) async {
    offsets = o..sort((a, b) => b.compareTo(a));
    await _commit();
  }

  /// FR-28: wipe everything local (cloud wipe comes with the backend).
  Future<void> deleteAll() async {
    for (final b in bills) {
      try {
        File(b.imagePath).deleteSync();
      } catch (_) {}
    }
    bills = [];
    items = [];
    await _commit();
  }

  Future<void> _commit() async {
    await _p.setString(
        'data',
        jsonEncode({
          'bills': bills.map((b) => b.toJson()).toList(),
          'items': items.map((i) => i.toJson()).toList(),
          'offsets': offsets,
        }));
    await _reschedule();
    await WidgetBridge.sync(this);
    notifyListeners();
    if (DriveSyncService.isAutoSyncEnabled) {
      DriveSyncService.autoBackup(this);
    }
  }

  /// Cancel-all then re-create: simple and correct for a few hundred reminders.
  Future<void> _reschedule() async {
    if (kIsWeb) return;
    await _n.cancelAll();
    final now = DateTime.now();
    var id = 0;
    for (final it in items) {
      final end = it.endDate;
      if (end == null) continue;
      for (final o in offsets) {
        final at = DateTime(end.year, end.month, end.day - o, 9);
        if (!at.isAfter(now)) continue;
        await _n.zonedSchedule(
          id: id++,
          title: o == 0 ? 'Warranty ends today' : 'Warranty ends in $o days',
          body: '${it.name} - keep the bill handy for any claim.',
          // Same instant, expressed in UTC, so no local-timezone plugin is needed.
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails('expiry', 'Warranty reminders',
                  importance: Importance.high),
              iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  /// Cloud sync provider hook (FR-27: Cloud Firestore & Firebase Auth sync).
  CloudSyncProvider? cloudSync;

  /// Trigger sync when online or cloud provider is connected.
  Future<void> syncCloud() async {
    if (cloudSync != null) {
      await cloudSync!.sync(bills: bills, items: items);
    }
  }
}

/// Abstract contract for Cloud Sync (Firestore, Supabase, or custom API backend).
abstract class CloudSyncProvider {
  Future<void> sync({required List<Bill> bills, required List<Item> items});
}

