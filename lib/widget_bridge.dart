import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'store.dart';

/// Bridges Flutter state to the native Android AppWidget without heavy plugins.
class WidgetBridge {
  static const _channel = MethodChannel('com.satyam.my_warranties/widget');
  static Future<void> sync(Store store) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final live = store.items.where((i) => i.status != WStatus.expired).toList()
        ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
      final next = live.firstOrNull;

      String nextSubtitle = '';
      if (next != null && next.endDate != null) {
        final brandPrefix = next.brand.isNotEmpty ? '${next.brand} · ' : '';
        nextSubtitle = '${brandPrefix}Ends ${store.formatDate(next.endDate!)}';
      }

      await _channel.invokeMethod('updateWidgetData', {
        'activeCount': live.length,
        'nextName': next?.name ?? '',
        'nextDays': next?.daysLeft ?? -1,
        'nextSubtitle': nextSubtitle,
      });
    } catch (e) {
      debugPrint('WidgetBridge sync error: $e');
    }
  }
}
