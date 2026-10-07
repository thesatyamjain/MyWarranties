import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'store.dart';

/// Clean Google Drive backup & restore service using personal Google Drive.
/// Uses 'drive.file' scope so app can only create & read files it created.
class DriveSyncService {
  static final _google = GoogleSignIn.instance;
  static bool _initialized = false;
  static GoogleSignInAccount? _currentUser;

  static const _scopes = [
    drive.DriveApi.driveFileScope,
  ];

  static const _backupJsonFileName = 'my_warranties_backup.json';
  static const _backupFolderName = 'My Warranties Vault';

  static const String serverClientId =
      '739225721782-hq8d17q5c3lm2pcqchs2g73m8ejie83j.apps.googleusercontent.com';

  static const _prefAutoSync = 'drive_auto_sync_enabled';
  static const _prefSignedInEmail = 'drive_signed_in_email';
  static const _prefSignedInName = 'drive_signed_in_name';
  static const _prefLastSync = 'drive_last_sync_timestamp';

  static bool _autoSyncEnabled = false;
  static DateTime? _lastSyncTime;
  static bool _isSyncing = false;
  static String? _savedEmail;
  static String? _savedName;

  static GoogleSignInAccount? get currentUser => _currentUser;
  static bool get isSignedIn => _currentUser != null || (_savedEmail != null && _savedEmail!.isNotEmpty);
  static String get userEmail => _currentUser?.email ?? _savedEmail ?? '';
  static String get userDisplayName => _currentUser?.displayName ?? _savedName ?? 'Google Account';
  static String? get savedEmail => _savedEmail;
  static bool get isAutoSyncEnabled => _autoSyncEnabled;
  static DateTime? get lastSyncTime => _lastSyncTime;
  static bool get isSyncing => _isSyncing;

  /// Load persisted sync and sign-in settings, restoring session silently
  static Future<void> initPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSyncEnabled = prefs.getBool(_prefAutoSync) ?? false;
      final lastMs = prefs.getInt(_prefLastSync);
      if (lastMs != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }
      _savedEmail = prefs.getString(_prefSignedInEmail);
      _savedName = prefs.getString(_prefSignedInName);
      if (_savedEmail != null && _savedEmail!.isNotEmpty) {
        await signInSilently();
      }
    } catch (e) {
      debugPrint('DriveSync initPrefs error: $e');
    }
  }

  static Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAutoSync, enabled);
    } catch (e) {
      debugPrint('Error saving auto-sync pref: $e');
    }
  }

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      await _google.initialize(
        serverClientId: serverClientId,
      );
      _initialized = true;

      // Synchronize state when authentication stream events fire
      _google.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _currentUser = event.user;
          _savedEmail = event.user.email;
          _savedName = event.user.displayName;
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _currentUser = null;
          _savedEmail = null;
          _savedName = null;
        }
      });
    } catch (e) {
      debugPrint('GoogleSignIn init error: $e');
    }
  }

  /// Attempt silent sign-in
  static Future<GoogleSignInAccount?> signInSilently() async {
    await _ensureInit();
    try {
      final acc = await _google.attemptLightweightAuthentication();
      if (acc != null) {
        _currentUser = acc;
        _savedEmail = acc.email;
        _savedName = acc.displayName;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefSignedInEmail, acc.email);
        if (acc.displayName != null) {
          await prefs.setString(_prefSignedInName, acc.displayName!);
        }
      }
      return _currentUser;
    } catch (e) {
      debugPrint('Silent Google Sign-In failed: $e');
      return null;
    }
  }

  /// Interactive sign-in
  static Future<GoogleSignInAccount?> signIn() async {
    await _ensureInit();
    try {
      final acc = await _google.authenticate(scopeHint: _scopes);
      _currentUser = acc;
      _savedEmail = acc.email;
      _savedName = acc.displayName;

      // Authorize scopes immediately in the same interactive gesture
      // so user isn't prompted again later on backup or sync!
      try {
        await acc.authorizationClient.authorizeScopes(_scopes);
      } catch (e) {
        debugPrint('Scope authorization notice: $e');
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefSignedInEmail, acc.email);
        if (acc.displayName != null) {
          await prefs.setString(_prefSignedInName, acc.displayName!);
        }
        // Default auto-sync to true if user hasn't toggled it yet
        if (prefs.getBool(_prefAutoSync) == null) {
          _autoSyncEnabled = true;
          await prefs.setBool(_prefAutoSync, true);
        }
      } catch (_) {}
      return acc;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    await _ensureInit();
    try {
      await _google.signOut();
      _currentUser = null;
      _savedEmail = null;
      _savedName = null;
      _autoSyncEnabled = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefSignedInEmail);
        await prefs.remove(_prefSignedInName);
        await prefs.setBool(_prefAutoSync, false);
      } catch (_) {}
    } catch (e) {
      debugPrint('Google Sign-Out error: $e');
    }
  }

  /// Get authenticated Drive API client
  static Future<drive.DriveApi?> _getDriveApi({bool allowInteractive = true}) async {
    await _ensureInit();
    var account = _currentUser;
    account ??= await signInSilently();
    if (account == null && allowInteractive) {
      account = await signIn();
    }
    if (account == null) return null;

    // Check if scopes are already authorized without prompting
    GoogleSignInClientAuthorization? authz =
        await account.authorizationClient.authorizationForScopes(_scopes);

    // If not authorized yet, request authorization only if interactive mode allowed
    if (authz == null) {
      if (!allowInteractive) return null;
      authz = await account.authorizationClient.authorizeScopes(_scopes);
    }

    final authClient = authz.authClient(scopes: _scopes);
    return drive.DriveApi(authClient);
  }

  /// Find or create dedicated vault folder on user's Google Drive
  static Future<String> _getOrCreateFolder(drive.DriveApi api) async {
    final query = "mimeType = 'application/vnd.google-apps.folder' and name = '$_backupFolderName' and trashed = false";
    final list = await api.files.list(q: query, spaces: 'drive');
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    final folder = drive.File()
      ..name = _backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id!;
  }

  /// Backup all bills and items to Google Drive
  static Future<({bool ok, String message, int count})> backup(Store store, {bool allowInteractive = true}) async {
    try {
      final api = await _getDriveApi(allowInteractive: allowInteractive);
      if (api == null) {
        return (ok: false, message: 'Google Sign-In required.', count: 0);
      }

      final folderId = await _getOrCreateFolder(api);

      // 1. Upload/Update JSON metadata
      final backupData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'bills': store.bills.map((b) => b.toJson()).toList(),
        'items': store.items.map((i) => i.toJson()).toList(),
      };
      final jsonBytes = utf8.encode(jsonEncode(backupData));
      final jsonMedia = drive.Media(
        Stream.value(jsonBytes),
        jsonBytes.length,
        contentType: 'application/json',
      );

      // Check if backup.json already exists in folder
      final query = "name = '$_backupJsonFileName' and '$folderId' in parents and trashed = false";
      final existingFiles = await api.files.list(q: query, spaces: 'drive');

      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        final fileId = existingFiles.files!.first.id!;
        await api.files.update(drive.File(), fileId, uploadMedia: jsonMedia);
      } else {
        final file = drive.File()
          ..name = _backupJsonFileName
          ..parents = [folderId];
        await api.files.create(file, uploadMedia: jsonMedia);
      }

      // 2. Upload missing bill images/PDFs
      int uploadedFiles = 0;
      final existingDriveFiles = await api.files.list(
        q: "'$folderId' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );
      final existingNames = {
        for (final f in (existingDriveFiles.files ?? []))
          if (f.name != null) f.name!: f.id
      };

      for (final bill in store.bills) {
        final localFile = File(bill.imagePath);
        if (!await localFile.exists()) continue;

        final fileName = localFile.uri.pathSegments.last;
        if (existingNames.containsKey(fileName)) continue; // already backed up

        final length = await localFile.length();
        final media = drive.Media(localFile.openRead(), length);
        final fileMeta = drive.File()
          ..name = fileName
          ..parents = [folderId];

        await api.files.create(fileMeta, uploadMedia: media);
        uploadedFiles++;
      }

      _lastSyncTime = DateTime.now();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefLastSync, _lastSyncTime!.millisecondsSinceEpoch);
      } catch (_) {}

      return (
        ok: true,
        message: 'Successfully backed up ${store.items.length} items to Google Drive.',
        count: store.items.length,
      );
    } catch (e) {
      debugPrint('Drive backup error: $e');
      return (ok: false, message: _formatDriveError(e, 'Backup'), count: 0);
    }
  }

  /// Restore bills and items from Google Drive
  static Future<({bool ok, String message, int count})> restore(Store store) async {
    _isSyncing = true;
    try {
      final api = await _getDriveApi(allowInteractive: true);
      if (api == null) {
        return (ok: false, message: 'Google Sign-In required.', count: 0);
      }

      final folderId = await _getOrCreateFolder(api);

      // 1. Locate backup.json
      final query = "name = '$_backupJsonFileName' and '$folderId' in parents and trashed = false";
      final files = await api.files.list(q: query, spaces: 'drive');
      if (files.files == null || files.files!.isEmpty) {
        return (ok: false, message: 'No backup found in your Google Drive.', count: 0);
      }

      final jsonFileId = files.files!.first.id!;
      final drive.Media media = await api.files.get(
        jsonFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final remoteBills = [for (final b in (j['bills'] as List? ?? [])) Bill.fromJson(b)];
      final remoteItems = [for (final i in (j['items'] as List? ?? [])) Item.fromJson(i)];

      // 2. Download any missing bill attachments to app documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      final allFolderFiles = await api.files.list(
        q: "'$folderId' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );
      final remoteFileMap = {
        for (final f in (allFolderFiles.files ?? []))
          if (f.name != null && f.id != null) f.name!: f.id!
      };

      for (final bill in remoteBills) {
        final expectedName = File(bill.imagePath).uri.pathSegments.last;
        final targetLocalFile = File('${docsDir.path}/$expectedName');

        // Update stored path to match current device's local docs path
        bill.imagePath = targetLocalFile.path;

        if (!await targetLocalFile.exists() && remoteFileMap.containsKey(expectedName)) {
          final fileId = remoteFileMap[expectedName]!;
          final drive.Media fileMedia = await api.files.get(
            fileId,
            downloadOptions: drive.DownloadOptions.fullMedia,
          ) as drive.Media;

          final sink = targetLocalFile.openWrite();
          await sink.addStream(fileMedia.stream);
          await sink.close();
        }
      }

      // Merge into local store
      int restoredCount = 0;
      for (final rb in remoteBills) {
        if (!store.bills.any((b) => b.id == rb.id)) {
          store.bills.add(rb);
        }
      }
      for (final ri in remoteItems) {
        if (!store.items.any((i) => i.id == ri.id)) {
          store.items.add(ri);
          restoredCount++;
        }
      }

      await store.update();

      _lastSyncTime = DateTime.now();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefLastSync, _lastSyncTime!.millisecondsSinceEpoch);
      } catch (_) {}

      return (
        ok: true,
        message: 'Successfully restored $restoredCount item(s) from Google Drive.',
        count: restoredCount,
      );
    } catch (e) {
      debugPrint('Drive restore error: $e');
      return (ok: false, message: _formatDriveError(e, 'Restore'), count: 0);
    } finally {
      _isSyncing = false;
    }
  }

  /// Background auto-sync triggered on warranty additions/edits/deletions.
  static Future<void> autoBackup(Store store) async {
    if (!_autoSyncEnabled || _isSyncing) return;
    _isSyncing = true;
    try {
      final res = await backup(store, allowInteractive: false);
      if (res.ok) {
        debugPrint('Auto-sync: successfully backed up to Google Drive');
      } else {
        debugPrint('Auto-sync skipped: ${res.message}');
      }
    } catch (e) {
      debugPrint('Auto-sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// True 2-Way Auto-Sync:
  /// 1. Silently pulls and merges any remote additions from Google Drive.
  /// 2. Automatically backs up any local changes that aren't on Drive yet.
  static Future<void> autoSync(Store store) async {
    if (!_autoSyncEnabled || _isSyncing) return;
    _isSyncing = true;
    try {
      final api = await _getDriveApi(allowInteractive: false);
      if (api == null) return;

      final folderId = await _getOrCreateFolder(api);

      // 1. Locate remote backup.json
      final query = "name = '$_backupJsonFileName' and '$folderId' in parents and trashed = false";
      final files = await api.files.list(q: query, spaces: 'drive');
      if (files.files != null && files.files!.isNotEmpty) {
        final jsonFileId = files.files!.first.id!;
        final drive.Media media = await api.files.get(
          jsonFileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;

        final bytes = <int>[];
        await for (final chunk in media.stream) {
          bytes.addAll(chunk);
        }

        final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final remoteBills = [for (final b in (j['bills'] as List? ?? [])) Bill.fromJson(b)];
        final remoteItems = [for (final i in (j['items'] as List? ?? [])) Item.fromJson(i)];

        final docsDir = await getApplicationDocumentsDirectory();
        final allFolderFiles = await api.files.list(
          q: "'$folderId' in parents and trashed = false",
          spaces: 'drive',
          $fields: 'files(id, name)',
        );
        final remoteFileMap = {
          for (final f in (allFolderFiles.files ?? []))
            if (f.name != null && f.id != null) f.name!: f.id!
        };

        bool hasNewRemote = false;
        for (final bill in remoteBills) {
          final expectedName = File(bill.imagePath).uri.pathSegments.last;
          final targetLocalFile = File('${docsDir.path}/$expectedName');
          bill.imagePath = targetLocalFile.path;

          if (!await targetLocalFile.exists() && remoteFileMap.containsKey(expectedName)) {
            final fileId = remoteFileMap[expectedName]!;
            final drive.Media fileMedia = await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            ) as drive.Media;

            final sink = targetLocalFile.openWrite();
            await sink.addStream(fileMedia.stream);
            await sink.close();
          }

          if (!store.bills.any((b) => b.id == bill.id)) {
            store.bills.add(bill);
            hasNewRemote = true;
          }
        }

        for (final ri in remoteItems) {
          if (!store.items.any((i) => i.id == ri.id)) {
            store.items.add(ri);
            hasNewRemote = true;
          }
        }

        if (hasNewRemote) {
          await store.update();
          debugPrint('Auto-sync: successfully pulled and merged remote items from Google Drive');
        }
      }

      // 2. Upload any local items not yet on Drive
      _isSyncing = false;
      await autoBackup(store);
    } catch (e) {
      debugPrint('Auto-sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  static String _formatDriveError(dynamic e, String action) {
    final str = e.toString();
    if (str.contains('16') || str.contains('Cancelled by user') || str.contains('access_denied') || str.contains('403')) {
      return '$action blocked: Google Cloud requires adding this account as a "Test user" in Google Cloud Console > OAuth consent screen (or Publish app to Production).';
    }
    if (str.contains('network') || str.contains('SocketException') || str.contains('Failed host lookup')) {
      return '$action failed: Check your internet connection and try again.';
    }
    return '$action failed: $str';
  }
}
