import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// Single source of truth for the installed application version
const String kCurrentAppVersion = '1.1.17';

class ReleaseInfo {
  final String tagName;
  final String title;
  final String notes;
  final String apkUrl;
  final int apkSize;
  final String htmlUrl;
  final DateTime? publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.title,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    required this.htmlUrl,
    this.publishedAt,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final assets = (json['assets'] as List<dynamic>?) ?? [];
    String apkUrl = '';
    int apkSize = 0;

    for (final a in assets) {
      final name = (a['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = a['browser_download_url'] as String? ?? '';
        apkSize = (a['size'] as num?)?.toInt() ?? 0;
        break;
      }
    }

    DateTime? pubDate;
    if (json['published_at'] != null) {
      pubDate = DateTime.tryParse(json['published_at'].toString());
    }

    return ReleaseInfo(
      tagName: (json['tag_name'] as String? ?? '').trim(),
      title: (json['name'] as String? ?? '').trim(),
      notes: (json['body'] as String? ?? '').trim(),
      apkUrl: apkUrl,
      apkSize: apkSize,
      htmlUrl: (json['html_url'] as String? ?? '').trim(),
      publishedAt: pubDate,
    );
  }
}

class OtaUpdateService {
  static const String _apiEndpoint =
      'https://api.github.com/repos/thesatyamjain/MyWarranties/releases/latest';
  static const String _prefLastCheck = 'ota_last_check_ms';

  /// Compare two semantic versions. Returns > 0 if v1 > v2, 0 if equal, < 0 if v1 < v2.
  static int compareVersions(String v1, String v2) {
    final clean1 = v1.replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final clean2 = v2.replaceFirst(RegExp(r'^[vV]'), '').split('+').first;

    final parts1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1.compareTo(p2);
    }
    return 0;
  }

  /// Checks GitHub API for the latest available release
  static Future<ReleaseInfo?> fetchLatestRelease() async {
    try {
      final res = await http.get(
        Uri.parse(_apiEndpoint),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          return ReleaseInfo.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('OTA check error: $e');
    }
    return null;
  }

  /// Determines if an update is available compared to the currently running version
  static Future<({bool hasUpdate, ReleaseInfo? release})> checkForUpdate() async {
    final release = await fetchLatestRelease();
    if (release == null || release.tagName.isEmpty) {
      return (hasUpdate: false, release: null);
    }

    final hasUpdate = compareVersions(release.tagName, kCurrentAppVersion) > 0;
    return (hasUpdate: hasUpdate, release: release);
  }

  /// Automatically checks for updates on app startup (throttled to once every 24 hours)
  static Future<ReleaseInfo?> checkOnLaunchThrottled() async {
    try {
      final p = await SharedPreferences.getInstance();
      final lastCheck = p.getInt(_prefLastCheck) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Throttle: check at most once every 24 hours
      if (now - lastCheck < 24 * 60 * 60 * 1000) {
        return null;
      }
      await p.setInt(_prefLastCheck, now);

      final result = await checkForUpdate();
      if (result.hasUpdate && result.release != null) {
        return result.release;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads the release APK with chunk streaming and live byte progress
  static Future<String?> downloadApk(
    String apkUrl, {
    required void Function(double progress, int received, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(apkUrl));
      final resp = await client.send(req);

      if (resp.statusCode != 200) {
        throw Exception('Download failed with HTTP ${resp.statusCode}');
      }

      final total = resp.contentLength ?? 0;
      Directory dir;
      try {
        final extDirs = await getExternalCacheDirectories();
        if (extDirs != null && extDirs.isNotEmpty) {
          dir = extDirs.first;
        } else {
          dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
        }
      } catch (_) {
        dir = await getTemporaryDirectory();
      }
      final filePath = '${dir.path}/my_warranties_update.apk';
      final file = File(filePath);

      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in resp.stream) {
        if (isCancelled()) {
          await sink.close();
          if (await file.exists()) await file.delete();
          return null;
        }
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress(received / total, received, total);
        }
      }

      await sink.flush();
      await sink.close();
      return filePath;
    } finally {
      client.close();
    }
  }

  /// Prompts Android Package Installer to install the downloaded APK
  static Future<bool> installApk(String filePath) async {
    if (kIsWeb) return false;

    // 1. Try native platform channel with direct FileProvider
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.thesoftwarelabs.mywarranties/installer');
        final success = await channel.invokeMethod<bool>('installApk', {'filePath': filePath});
        if (success == true) return true;
      } catch (e) {
        debugPrint('Native installer channel attempt failed: $e, falling back to open_filex');
      }
    }

    // 2. Fallback to OpenFilex
    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Error launching installer: $e');
      return false;
    }
  }
}

/// Displays the interactive OTA update bottom sheet
Future<void> showOtaUpdateSheet(
  BuildContext context, {
  ReleaseInfo? initialRelease,
  bool manualCheck = true,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OtaUpdateSheet(
      initialRelease: initialRelease,
      manualCheck: manualCheck,
    ),
  );
}

class _OtaUpdateSheet extends StatefulWidget {
  final ReleaseInfo? initialRelease;
  final bool manualCheck;

  const _OtaUpdateSheet({
    this.initialRelease,
    required this.manualCheck,
  });

  @override
  State<_OtaUpdateSheet> createState() => _OtaUpdateSheetState();
}

class _OtaUpdateSheetState extends State<_OtaUpdateSheet> {
  bool _loading = false;
  String? _errorMessage;
  ReleaseInfo? _release;
  bool _hasUpdate = false;

  // Download state
  bool _downloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedFilePath;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRelease != null) {
      _release = widget.initialRelease;
      _hasUpdate = OtaUpdateService.compareVersions(
              widget.initialRelease!.tagName, kCurrentAppVersion) >
          0;
    } else {
      _fetchUpdate();
    }
  }

  Future<void> _fetchUpdate() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await OtaUpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _release = result.release;
        _hasUpdate = result.hasUpdate;
        if (result.release == null) {
          _errorMessage =
              'Could not reach update server. Check your internet connection.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to check for updates: $e';
      });
    }
  }

  Future<void> _startDownload() async {
    if (_release == null || _release!.apkUrl.isEmpty) {
      // Fallback: open release page in browser
      if (_release?.htmlUrl.isNotEmpty == true) {
        launchUrl(Uri.parse(_release!.htmlUrl),
            mode: LaunchMode.externalApplication);
      }
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = _release!.apkSize;
      _cancelled = false;
      _errorMessage = null;
    });

    try {
      final path = await OtaUpdateService.downloadApk(
        _release!.apkUrl,
        onProgress: (p, rec, tot) {
          if (mounted) {
            setState(() {
              _progress = p;
              _receivedBytes = rec;
              _totalBytes = tot;
            });
          }
        },
        isCancelled: () => _cancelled,
      );

      if (!mounted) return;

      if (path != null) {
        setState(() {
          _downloading = false;
          _downloadedFilePath = path;
        });
        await OtaUpdateService.installApk(path);
      } else {
        setState(() {
          _downloading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _errorMessage = 'Download error: $e';
      });
    }
  }

  void _cancelDownload() {
    setState(() {
      _cancelled = true;
      _downloading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Pal.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Pal.line.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Pal.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Pal.line.withValues(alpha: 0.4)),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.arrow_down_circle_fill,
                    color: Pal.blue,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Software Update',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current version: v$kCurrentAppVersion',
                      style: const TextStyle(fontSize: 13, color: Pal.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill,
                    color: Pal.line),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Body Content depending on state
          if (_loading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Checking for updates...',
                    style: TextStyle(
                        fontSize: 14,
                        color: Pal.muted,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ] else if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Pal.brick.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Pal.r),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                      color: Pal.brick, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Pal.brick,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _fetchUpdate,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Pal.r)),
              ),
              child: const Text('Try Again'),
            ),
          ] else if (!_hasUpdate) ...[
            // Up to date state
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Pal.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Pal.green.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Pal.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.checkmark_alt,
                        color: Pal.green, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'My Warranties is Up to Date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Pal.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You have the latest version (v$kCurrentAppVersion) with all active features and security patches.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: Pal.muted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: Pal.paper,
                foregroundColor: Pal.ink,
                elevation: 0,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Pal.r)),
              ),
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ] else ...[
            // Update available state
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Pal.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Pal.blue.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Pal.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _release?.tagName ?? 'New Update',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_release != null && _release!.apkSize > 0)
                        Text(
                          _formatBytes(_release!.apkSize),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Pal.muted,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _release?.title.isNotEmpty == true
                        ? _release!.title
                        : 'New Features & Enhancements Available',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (_release?.notes.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SingleChildScrollView(
                        child: Text(
                          _release!.notes,
                          style: const TextStyle(
                              fontSize: 13, color: Pal.muted, height: 1.35),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Download progress indicator
            if (_downloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 8,
                      backgroundColor: Pal.paper,
                      valueColor: const AlwaysStoppedAnimation<Color>(Pal.blue),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading update: ${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Pal.blue),
                      ),
                      Text(
                        '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                        style: const TextStyle(fontSize: 12, color: Pal.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _cancelDownload,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Pal.r)),
                    ),
                    child: const Text('Cancel Download'),
                  ),
                ],
              ),
            ] else if (_downloadedFilePath != null) ...[
              // Download finished, ready to re-trigger install
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Pal.paper,
                      borderRadius: BorderRadius.circular(Pal.r),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(CupertinoIcons.info_circle, size: 18, color: Pal.muted),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Package downloaded. If Android says "App not installed", uninstall any previous debug version first, then tap Open Installer below.',
                            style: TextStyle(fontSize: 12, color: Pal.muted, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await OtaUpdateService.installApk(_downloadedFilePath!);
                      if (!ok && mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Could not launch installer. Use "Download via Browser" below or open from Files app.',
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Pal.brick,
                          ),
                        );
                      }
                    },
                    icon: const Icon(CupertinoIcons.play_arrow_solid, size: 16),
                    label: const Text('Open Package Installer'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Pal.r)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_release?.apkUrl.isNotEmpty == true)
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(_release!.apkUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(CupertinoIcons.globe, size: 16),
                      label: const Text('Download via Browser'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Pal.r)),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ] else ...[
              // Action buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(CupertinoIcons.arrow_down_to_line,
                        size: 16),
                    label: const Text('Download & Update (OTA)'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Pal.r)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_release?.htmlUrl.isNotEmpty == true)
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(_release!.htmlUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text(
                        'View Release on GitHub',
                        style: TextStyle(
                            color: Pal.muted, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
