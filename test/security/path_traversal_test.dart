import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Backup Path Traversal Protection Logic', () {
    late Directory tempRootDir;
    late Directory backupsDir;

    setUp(() {
      tempRootDir = Directory.systemTemp.createTempSync('atv_security_test_');
      backupsDir = Directory('${tempRootDir.path}${Platform.pathSeparator}backups');
      backupsDir.createSync(recursive: true);
    });

    tearDown(() {
      try {
        if (tempRootDir.existsSync()) {
          tempRootDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    // Helper simulating Native Android / Dart readLocalBackup validation
    String? simulateReadLocalBackup(String? fileName) {
      if (fileName == null || fileName.trim().isEmpty) {
        return '';
      }
      final sanitizedName = File(fileName).uri.pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );
      if (sanitizedName.isEmpty || !sanitizedName.endsWith('.json')) {
        return '';
      }
      final file = File('${backupsDir.path}${Platform.pathSeparator}$sanitizedName');
      if (!file.existsSync()) {
        return '';
      }
      try {
        final canonicalFilePath = file.resolveSymbolicLinksSync();
        final canonicalDirPath = backupsDir.resolveSymbolicLinksSync();
        if (!canonicalFilePath.startsWith('$canonicalDirPath${Platform.pathSeparator}')) {
          return '';
        }
        return file.readAsStringSync();
      } catch (_) {
        return '';
      }
    }

    // Helper simulating Native Android / Dart deleteLocalBackup validation
    bool simulateDeleteLocalBackup(String? fileName) {
      if (fileName == null || fileName.trim().isEmpty) {
        return false;
      }
      final sanitizedName = File(fileName).uri.pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );
      if (sanitizedName.isEmpty || !sanitizedName.endsWith('.json')) {
        return false;
      }
      final file = File('${backupsDir.path}${Platform.pathSeparator}$sanitizedName');
      if (!file.existsSync()) {
        return false;
      }
      try {
        final canonicalFilePath = file.resolveSymbolicLinksSync();
        final canonicalDirPath = backupsDir.resolveSymbolicLinksSync();
        if (!canonicalFilePath.startsWith('$canonicalDirPath${Platform.pathSeparator}')) {
          return false;
        }
        file.deleteSync();
        return true;
      } catch (_) {
        return false;
      }
    }

    // Helper simulating Native Android sanitizeBackupFileName
    String simulateSanitizeBackupFileName(String? fileName) {
      String resolvedName;
      if (fileName == null || fileName.trim().isEmpty) {
        resolvedName = 'atv-launcher-backup.json';
      } else {
        resolvedName = File(fileName).uri.pathSegments.lastWhere(
              (s) => s.isNotEmpty,
              orElse: () => 'atv-launcher-backup.json',
            );
      }
      if (!resolvedName.endsWith('.json')) {
        resolvedName = '$resolvedName.json';
      }
      return resolvedName;
    }

    test('readLocalBackup rejects path traversal attacks attempting to escape backup dir', () {
      // Create a secret file outside backups directory
      final secretFile = File('${tempRootDir.path}${Platform.pathSeparator}secret.json');
      secretFile.writeAsStringSync('{"secret": "sensitive_data"}');

      // Valid backup file inside backups directory
      final validBackup = File('${backupsDir.path}${Platform.pathSeparator}valid_backup.json');
      validBackup.writeAsStringSync('{"backup": "ok"}');

      // Valid read succeeds
      expect(simulateReadLocalBackup('valid_backup.json'), '{"backup": "ok"}');

      // Traversal attacks with ../
      expect(simulateReadLocalBackup('../secret.json'), '');
      expect(simulateReadLocalBackup('../../secret.json'), '');
      expect(simulateReadLocalBackup('..\\secret.json'), '');
      expect(simulateReadLocalBackup('/etc/passwd'), '');
      expect(simulateReadLocalBackup('C:\\Windows\\win.ini'), '');
      expect(simulateReadLocalBackup(null), '');
      expect(simulateReadLocalBackup(''), '');
      expect(simulateReadLocalBackup('   '), '');
    });

    test('readLocalBackup enforces .json extension and rejects non-json files', () {
      final textFile = File('${backupsDir.path}${Platform.pathSeparator}payload.sh');
      textFile.writeAsStringSync('echo malicious');

      final dbFile = File('${backupsDir.path}${Platform.pathSeparator}launcher.db');
      dbFile.writeAsStringSync('sqlite data');

      expect(simulateReadLocalBackup('payload.sh'), '');
      expect(simulateReadLocalBackup('launcher.db'), '');
      expect(simulateReadLocalBackup('payload.sh.exe'), '');
      expect(simulateReadLocalBackup('backup.txt'), '');
    });

    test('deleteLocalBackup rejects path traversal attacks and prevents arbitrary file deletion', () {
      // Create a critical file outside backups directory
      final criticalFile = File('${tempRootDir.path}${Platform.pathSeparator}database.json');
      criticalFile.writeAsStringSync('{"critical": true}');

      // Create a legitimate backup file
      final legitimateFile = File('${backupsDir.path}${Platform.pathSeparator}old_backup.json');
      legitimateFile.writeAsStringSync('{"old": true}');

      // Traversal attack to delete file outside backup dir fails
      expect(simulateDeleteLocalBackup('../database.json'), isFalse);
      expect(criticalFile.existsSync(), isTrue);

      // Traversal with multiple ../ fails
      expect(simulateDeleteLocalBackup('../../../database.json'), isFalse);
      expect(criticalFile.existsSync(), isTrue);

      // Non-json deletion fails
      final otherFile = File('${backupsDir.path}${Platform.pathSeparator}notes.txt');
      otherFile.writeAsStringSync('notes');
      expect(simulateDeleteLocalBackup('notes.txt'), isFalse);
      expect(otherFile.existsSync(), isTrue);

      // Legitimate deletion succeeds
      expect(simulateDeleteLocalBackup('old_backup.json'), isTrue);
      expect(legitimateFile.existsSync(), isFalse);

      // Non-existent file returns false safely
      expect(simulateDeleteLocalBackup('non_existent.json'), isFalse);
      expect(simulateDeleteLocalBackup(null), isFalse);
      expect(simulateDeleteLocalBackup(''), isFalse);
    });

    test('sanitizeBackupFileName strips directory traversal and guarantees .json suffix', () {
      expect(
        simulateSanitizeBackupFileName('../../../etc/passwd'),
        'passwd.json',
      );
      expect(
        simulateSanitizeBackupFileName('..\\..\\sensitive_file.txt'),
        'sensitive_file.txt.json',
      );
      expect(
        simulateSanitizeBackupFileName('my_backup'),
        'my_backup.json',
      );
      expect(
        simulateSanitizeBackupFileName('my_backup.json'),
        'my_backup.json',
      );
      expect(
        simulateSanitizeBackupFileName(''),
        'atv-launcher-backup.json',
      );
      expect(
        simulateSanitizeBackupFileName(null),
        'atv-launcher-backup.json',
      );
    });
  });

  group('Video Wallpaper Path & URI Security Verification Logic', () {
    const allowedExtensions = {
      '.mp4',
      '.mkv',
      '.webm',
      '.avi',
      '.ts',
      '.m2ts',
      '.m4v',
      '.3gp',
      '.mov',
    };

    bool hasAllowedVideoExtension(String path) {
      final lower = path.toLowerCase();
      return allowedExtensions.any((ext) => lower.endsWith(ext));
    }

    bool isSystemBlacklisted(String canonicalPath) {
      final path = canonicalPath.replaceAll('\\', '/');
      return path == '/proc' ||
          path.startsWith('/proc/') ||
          path == '/sys' ||
          path.startsWith('/sys/') ||
          path == '/dev' ||
          path.startsWith('/dev/') ||
          path == '/system' ||
          path.startsWith('/system/') ||
          path == '/etc' ||
          path.startsWith('/etc/');
    }

    bool isSafeVideoUri({
      required String uriStr,
      required String packageName,
      required String wallpaperAssetsDir,
      required List<String> whitelistedMounts,
    }) {
      if (uriStr.trim().isEmpty) return false;

      // 1. SAF / MediaStore content URIs
      if (uriStr.startsWith('content://')) {
        return uriStr.startsWith('content://media') ||
            uriStr.startsWith('content://com.android.externalstorage.documents');
      }

      // 2. File paths
      String filePath;
      if (uriStr.startsWith('file://')) {
        filePath = Uri.parse(uriStr).toFilePath(windows: Platform.isWindows);
      } else if (uriStr.startsWith('/')) {
        filePath = uriStr;
      } else {
        return false;
      }

      if (!hasAllowedVideoExtension(filePath)) {
        return false;
      }

      // Canonical path check (normalize slashes)
      final normalized = filePath.replaceAll('\\', '/');

      if (isSystemBlacklisted(normalized)) {
        return false;
      }

      // Private app storage check
      final user0Pkg = '/data/user/0/$packageName';
      final dataPkg = '/data/data/$packageName';
      if (normalized.startsWith(user0Pkg) || normalized.startsWith(dataPkg)) {
        // Only allowed if strictly inside internal wallpaper_assets
        if (normalized.startsWith('$wallpaperAssetsDir/')) {
          return true;
        }
        return false;
      }

      // Storage whitelist check
      for (final mount in whitelistedMounts) {
        if (normalized == mount || normalized.startsWith('$mount/')) {
          return true;
        }
      }

      return false;
    }

    test('whitelists standard SAF and MediaStore content URIs', () {
      expect(
        isSafeVideoUri(
          uriStr: 'content://media/external/video/media/1234',
          packageName: 'com.atv.launcher',
          wallpaperAssetsDir: '/data/user/0/com.atv.launcher/files/wallpaper_assets',
          whitelistedMounts: ['/storage/emulated/0'],
        ),
        isTrue,
      );

      expect(
        isSafeVideoUri(
          uriStr: 'content://com.android.externalstorage.documents/document/primary%3AVideos%2Ftest.mp4',
          packageName: 'com.atv.launcher',
          wallpaperAssetsDir: '/data/user/0/com.atv.launcher/files/wallpaper_assets',
          whitelistedMounts: ['/storage/emulated/0'],
        ),
        isTrue,
      );
    });

    test('accepts valid video extensions in whitelisted public and external storage', () {
      final mounts = ['/storage/emulated/0', '/storage/1A2B-3C4D'];

      for (final ext in allowedExtensions) {
        expect(
          isSafeVideoUri(
            uriStr: '/storage/emulated/0/Movies/sample$ext',
            packageName: 'com.atv.launcher',
            wallpaperAssetsDir: '/data/user/0/com.atv.launcher/files/wallpaper_assets',
            whitelistedMounts: mounts,
          ),
          isTrue,
          reason: 'Extension $ext should be allowed in public storage',
        );

        expect(
          isSafeVideoUri(
            uriStr: 'file:///storage/1A2B-3C4D/DCIM/clip$ext',
            packageName: 'com.atv.launcher',
            wallpaperAssetsDir: '/data/user/0/com.atv.launcher/files/wallpaper_assets',
            whitelistedMounts: mounts,
          ),
          isTrue,
          reason: 'Extension $ext should be allowed in USB mount',
        );
      }
    });

    test('strictly blocks private application directory access outside wallpaper_assets', () {
      const pkg = 'com.atv.launcher';
      const assetsDir = '/data/user/0/$pkg/files/wallpaper_assets';

      // Forbidden access to app databases
      expect(
        isSafeVideoUri(
          uriStr: '/data/user/0/$pkg/databases/launcher.db.mp4',
          packageName: pkg,
          wallpaperAssetsDir: assetsDir,
          whitelistedMounts: ['/storage/emulated/0'],
        ),
        isFalse,
      );

      // Forbidden access to shared_prefs
      expect(
        isSafeVideoUri(
          uriStr: '/data/data/$pkg/shared_prefs/prefs.xml.mp4',
          packageName: pkg,
          wallpaperAssetsDir: assetsDir,
          whitelistedMounts: ['/storage/emulated/0'],
        ),
        isFalse,
      );

      // Allowed access to legitimate internal wallpaper assets
      expect(
        isSafeVideoUri(
          uriStr: '$assetsDir/bundled_ambient.mp4',
          packageName: pkg,
          wallpaperAssetsDir: assetsDir,
          whitelistedMounts: ['/storage/emulated/0'],
        ),
        isTrue,
      );
    });

    test('strictly blocks system paths and dangerous extensions', () {
      const mounts = ['/storage/emulated/0'];
      const assetsDir = '/data/user/0/com.atv.launcher/files/wallpaper_assets';

      // System root paths
      expect(
        isSafeVideoUri(
          uriStr: '/proc/version.mp4',
          packageName: 'com.atv.launcher',
          wallpaperAssetsDir: assetsDir,
          whitelistedMounts: mounts,
        ),
        isFalse,
      );
      expect(
        isSafeVideoUri(
          uriStr: '/dev/urandom.mp4',
          packageName: 'com.atv.launcher',
          wallpaperAssetsDir: assetsDir,
          whitelistedMounts: mounts,
        ),
        isFalse,
      );
      expect(
        isSafeVideoUri(
          uriStr: '/system/bin/sh.mp4',
          packageName: 'com.atv.launcher',
          wallpaperAssetsDir: assetsDir,
          whitelistedMounts: mounts,
        ),
        isFalse,
      );

      // Dangerous non-video extensions even in public storage
      expect(
        isSafeVideoUri(
          uriStr: '/storage/emulated/0/Download/exploit.apk',
          packageName: 'com.atv.launcher',
          wallpaperAssetsDir: assetsDir,
          whitelistedMounts: mounts,
        ),
        isFalse,
      );
      expect(
        isSafeVideoUri(
          uriStr: '/storage/emulated/0/Download/script.sh',
          packageName: 'com.atv.launcher',
          wallpaperAssetsDir: assetsDir,
          whitelistedMounts: mounts,
        ),
        isFalse,
      );
      expect(
        isSafeVideoUri(
          uriStr: '/storage/emulated/0/Download/payload.dex',
          packageName: 'com.atv.launcher',
          wallpaperAssetsDir: assetsDir,
          whitelistedMounts: mounts,
        ),
        isFalse,
      );
    });
  });

  group('Static Security Assertions on Native Java Implementation', () {
    test('VideoSecurityValidator declares whitelisted extensions and boundary checks', () {
      final file = File(
        'android/app/src/main/java/com/atv/launcher/systembridge/wallpaper/VideoSecurityValidator.java',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('ALLOWED_EXTENSIONS'));
      expect(content, contains('.mp4'));
      expect(content, contains('.mkv'));
      expect(content, contains('.webm'));
      expect(content, contains('.mov'));
      expect(content, contains('isUriSafeForPlayback'));
      expect(content, contains('isSystemBlacklisted'));
      expect(content, contains('/proc'));
      expect(content, contains('/sys'));
      expect(content, contains('/dev'));
      expect(content, contains('/system'));
      expect(content, contains('wallpaper_assets'));
      expect(content, contains('/storage/emulated/0'));
      expect(content, contains('getCanonicalPath()'));
    });

    test('VideoWallpaperController integrates VideoSecurityValidator and URI quarantine', () {
      final file = File(
        'android/app/src/main/java/com/atv/launcher/systembridge/wallpaper/VideoWallpaperController.java',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('VideoSecurityValidator.isUriSafeForPlayback'));
      expect(content, contains('quarantinedUris'));
    });

    test('MainActivity sanitizes backup file names against path traversal', () {
      final file = File(
        'android/app/src/main/java/com/atv/launcher/MainActivity.java',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('sanitizeBackupFileName'));
      expect(content, contains('readLocalBackup'));
      expect(content, contains('deleteLocalBackup'));
      expect(content, contains('new File(fileName).getName()'));
    });
  });
}
