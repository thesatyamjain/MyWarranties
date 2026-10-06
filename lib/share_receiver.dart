import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'add_flow.dart';
import 'store.dart';

/// Handles receiving shared images and PDFs from external apps (WhatsApp, Gallery, Files, Drive, etc.)
class ShareReceiver {
  static const _channel = MethodChannel('com.thesoftwarelabs.mywarranties/share');
  static bool _listening = false;

  /// Check if the app was launched by receiving shared file(s)
  static Future<List<String>> getInitialSharedFiles() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final List? files = await _channel.invokeMethod<List>('getInitialSharedFiles');
      return files?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      debugPrint('ShareReceiver getInitialSharedFiles error: $e');
      return [];
    }
  }

  /// Listen for incoming shared files while the app is active or launched
  static void initialize(BuildContext context, Store store) {
    if (kIsWeb || !Platform.isAndroid) return;

    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onFilesShared') {
          final List? files = call.arguments as List?;
          final paths = files?.map((e) => e.toString()).toList() ?? [];
          if (paths.isNotEmpty && context.mounted) {
            handleIncomingSharedFiles(context, store, paths);
          }
        }
      });
    }

    // Process any files that launched the app
    getInitialSharedFiles().then((paths) {
      if (paths.isNotEmpty && context.mounted) {
        handleIncomingSharedFiles(context, store, paths);
      }
    });
  }

  /// Route shared files directly to ProcessingScreen for optical scanning and AI extraction
  static void handleIncomingSharedFiles(BuildContext context, Store store, List<String> paths) {
    for (final p in paths) {
      final file = File(p);
      if (file.existsSync()) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProcessingScreen(store: store, file: file),
          ),
        );
      }
    }
  }
}
