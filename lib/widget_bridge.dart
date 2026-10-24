import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'store.dart';

/// Bridges Flutter state to the native Android AppWidget without heavy plugins.
class WidgetBridge {
  static const _channel = MethodChannel('com.thesoftwarelabs.mywarranties/widget');
  static Future<void> sync(Store store) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final active = store.activeItems;
      active.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
      final nextExpiring = active.isNotEmpty ? active.first : null;

      await _channel.invokeMethod('updateWidgetData', {
        'totalCount': active.length,
        'nextName': nextExpiring?.name ?? '',
        'nextBrand': nextExpiring?.brand ?? '',
        'nextCountdown': nextExpiring != null ? countdown(nextExpiring.daysLeft) : '',
        'statusColor': nextExpiring != null
            ? (nextExpiring.status == WStatus.expired
                ? 'expired'
                : (nextExpiring.status == WStatus.expiringSoon ? 'expiring' : 'active'))
            : 'empty',
      });
    } catch (e) {
      debugPrint('WidgetBridge sync error: $e');
    }
  }
}
