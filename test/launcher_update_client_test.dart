import 'package:flauncher/launcher_update_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LauncherUpdateRelease', () {
    test('skips debug releases and picks the newest official release', () {
      final releases = <LauncherUpdateRelease>[
        LauncherUpdateRelease.fromGitHubJson({
          'tag_name': 'v2026.04.30-debug',
          'name': 'ATV Launcher Debug',
          'html_url': 'https://example.com/debug',
          'published_at': '2026-04-30T10:00:00Z',
          'body': '',
          'assets': [
            {
              'name': 'atv-launcher-armeabi-v7a-debug.apk',
              'browser_download_url': 'https://example.com/debug.apk',
              'size': 123,
              'download_count': 50,
              'content_type': 'application/vnd.android.package-archive',
            },
          ],
        }),
        LauncherUpdateRelease.fromGitHubJson({
          'tag_name': 'v2026.04.29-release',
          'name': 'ATV Launcher Release',
          'html_url': 'https://example.com/release',
          'published_at': '2026-04-29T10:00:00Z',
          'body': '',
          'assets': [
            {
              'name': 'atv-launcher-armeabi-v7a-release.apk',
              'browser_download_url': 'https://example.com/release.apk',
              'size': 456,
              'download_count': 10,
              'content_type': 'application/vnd.android.package-archive',
            },
          ],
        }),
      ];

      final selected =
          LauncherUpdateRelease.pickLatestOfficialRelease(releases);

      expect(selected?.tagName, 'v2026.04.29-release');
    });

    test('prefers release APK assets over debug assets', () {
      final release = LauncherUpdateRelease.fromGitHubJson({
        'tag_name': 'v2026.04.30-release',
        'name': 'ATV Launcher Release',
        'html_url':
            'https://github.com/xfire0392-netizen/atv-launcher/releases/tag/v2026.04.30-release',
        'published_at': '2026-04-30T10:00:00Z',
        'body': 'Release notes',
        'assets': [
          {
            'name': 'atv-launcher-armeabi-v7a-debug.apk',
            'browser_download_url': 'https://example.com/debug.apk',
            'size': 123,
            'download_count': 50,
            'content_type': 'application/vnd.android.package-archive',
          },
          {
            'name': 'atv-launcher-armeabi-v7a-release.apk',
            'browser_download_url': 'https://example.com/release.apk',
            'size': 456,
            'download_count': 10,
            'content_type': 'application/vnd.android.package-archive',
          },
        ],
      });

      expect(
        release.preferredApkAsset?.name,
        'atv-launcher-armeabi-v7a-release.apk',
      );
    });

    test('returns no preferred asset when only debug APKs exist', () {
      final release = LauncherUpdateRelease.fromGitHubJson({
        'tag_name': 'v2026.04.30-release',
        'name': 'ATV Launcher Release',
        'html_url': 'https://example.com',
        'published_at': '2026-04-30T10:00:00Z',
        'body': '',
        'assets': [
          {
            'name': 'atv-launcher-armeabi-v7a-debug.apk',
            'browser_download_url': 'https://example.com/debug.apk',
            'size': 123,
            'download_count': 50,
            'content_type': 'application/vnd.android.package-archive',
          },
        ],
      });

      expect(release.preferredApkAsset, isNull);
      expect(release.isOfficialRelease, isFalse);
    });

    test('matches installed version using normalized tag tokens', () {
      final release = LauncherUpdateRelease.fromGitHubJson({
        'tag_name': 'v2024.11.001-release',
        'name': 'ATV Launcher v2024.11.001',
        'html_url': 'https://example.com',
        'published_at': '2026-04-30T10:00:00Z',
        'body': '',
        'assets': [
          {
            'name': 'atv-launcher-v2024.11.001-release.apk',
            'browser_download_url': 'https://example.com/release.apk',
            'size': 456,
            'download_count': 10,
            'content_type': 'application/vnd.android.package-archive',
          },
        ],
      });

      expect(release.matchesInstalledVersion('2024.11.001+15'), isTrue);
      expect(release.matchesInstalledVersion('2025.01.002+1'), isFalse);
    });
  });

  group('formatUpdateFileSize', () {
    test('formats human readable sizes', () {
      expect(formatUpdateFileSize(0), '0 B');
      expect(formatUpdateFileSize(1024), '1 KB');
      expect(formatUpdateFileSize(1536), '1.5 KB');
      expect(formatUpdateFileSize(2 * 1024 * 1024), '2 MB');
    });
  });
}
