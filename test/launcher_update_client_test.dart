import 'dart:convert';
import 'dart:io';

import 'package:flauncher/launcher_update_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const officialMarker = LauncherUpdateClient.officialChannelMarker;

  group('LauncherUpdateRelease', () {
    test('skips debug releases and picks the newest official release', () {
      final releases = <LauncherUpdateRelease>[
        LauncherUpdateRelease.fromGitHubJson({
          'tag_name': 'v2026.04.30-debug',
          'name': 'ATV Launcher Debug',
          'html_url': 'https://example.com/debug',
          'published_at': '2026-04-30T10:00:00Z',
          'body': officialMarker,
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
          'body': officialMarker,
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

    test('sorts official releases by newest publish time and version', () {
      final releases = <LauncherUpdateRelease>[
        LauncherUpdateRelease.fromGitHubJson({
          'tag_name': 'v2026.05.001-release',
          'name': 'ATV Launcher xfire0392-netizen v2026.05.001',
          'html_url': 'https://example.com/release-001',
          'published_at': '2026-04-30T18:20:01Z',
          'body': officialMarker,
          'assets': [
            {
              'name': 'atv-launcher-armeabi-v7a-release.apk',
              'browser_download_url': 'https://example.com/release-001.apk',
              'size': 123,
              'download_count': 1,
              'content_type': 'application/vnd.android.package-archive',
            },
          ],
        }),
        LauncherUpdateRelease.fromGitHubJson({
          'tag_name': 'v2026.05.002-release',
          'name': 'ATV Launcher xfire0392-netizen v2026.05.002',
          'html_url': 'https://example.com/release-002',
          'published_at': '2026-04-30T23:18:39Z',
          'body': officialMarker,
          'assets': [
            {
              'name': 'atv-launcher-armeabi-v7a-release.apk',
              'browser_download_url': 'https://example.com/release-002.apk',
              'size': 456,
              'download_count': 0,
              'content_type': 'application/vnd.android.package-archive',
            },
          ],
        }),
      ];

      final selected = LauncherUpdateRelease.pickLatestOfficialRelease(
        releases.reversed,
      );

      expect(selected?.tagName, 'v2026.05.002-release');
    });

    test('prefers release APK assets over debug assets', () {
      final release = LauncherUpdateRelease.fromGitHubJson({
        'tag_name': 'v2026.04.30-release',
        'name': 'ATV Launcher Release',
        'html_url':
            'https://github.com/xfire0392-netizen/atv-launcher/releases/tag/v2026.04.30-release',
        'published_at': '2026-04-30T10:00:00Z',
        'body': 'Release notes\n$officialMarker',
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

    test(
        'prefers armeabi release asset over more downloaded universal release asset',
        () {
      final release = LauncherUpdateRelease.fromGitHubJson({
        'tag_name': 'v2026.04.30-release',
        'name': 'ATV Launcher Release',
        'html_url': 'https://example.com/release',
        'published_at': '2026-04-30T10:00:00Z',
        'body': officialMarker,
        'assets': [
          {
            'name': 'atv-launcher-universal-release.apk',
            'browser_download_url': 'https://example.com/universal.apk',
            'size': 999,
            'download_count': 500,
            'content_type': 'application/vnd.android.package-archive',
          },
          {
            'name': 'atv-launcher-armeabi-v7a-release.apk',
            'browser_download_url': 'https://example.com/arm.apk',
            'size': 456,
            'download_count': 1,
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
        'body': officialMarker,
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
        'body': officialMarker,
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

    test('does not treat legacy unmarked releases as official', () {
      final release = LauncherUpdateRelease.fromGitHubJson({
        'tag_name': 'v2026.04.30-release',
        'name': 'ATV Launcher Release',
        'html_url': 'https://example.com/release',
        'published_at': '2026-04-30T10:00:00Z',
        'body': 'Legacy release body without channel marker',
        'assets': [
          {
            'name': 'atv-launcher-armeabi-v7a-release.apk',
            'browser_download_url': 'https://example.com/release.apk',
            'size': 456,
            'download_count': 10,
            'content_type': 'application/vnd.android.package-archive',
          },
        ],
      });

      expect(release.isOfficialRelease, isFalse);
    });

    test('accepts markdown formatted updater-channel markers', () {
      final release = LauncherUpdateRelease.fromGitHubJson({
        'tag_name': 'v2026.05.003-release',
        'name': 'ATV Launcher xfire0392-netizen v2026.05.003',
        'html_url': 'https://example.com/release',
        'published_at': '2026-05-01T03:57:16Z',
        'body':
            'Updater-Channel: `xfire0392-netizen-official`\nOfficial release',
        'assets': [
          {
            'name': 'atv-launcher-armeabi-v7a-release.apk',
            'browser_download_url': 'https://example.com/release.apk',
            'size': 456,
            'download_count': 10,
            'content_type': 'application/vnd.android.package-archive',
          },
        ],
      });

      expect(release.isOfficialRelease, isTrue);
    });
  });

  group('LauncherUpdateClient', () {
    test(
        'fetchLatestOfficialRelease paginates until it finds an official release',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      final requestedPages = <String>[];
      server.listen((request) async {
        requestedPages.add(request.uri.queryParameters['page'] ?? '');
        final page =
            int.tryParse(request.uri.queryParameters['page'] ?? '1') ?? 1;
        final response = request.response;
        response.headers.contentType = ContentType.json;
        if (page == 1) {
          final debugReleases = List.generate(
            LauncherUpdateClient.releasePageSize,
            (index) => <String, dynamic>{
              'tag_name': 'v2026.04.${index + 1}-debug',
              'name': 'ATV Launcher Debug',
              'html_url': 'https://example.com/debug/$index',
              'published_at': '2026-04-30T10:00:00Z',
              'body': officialMarker,
              'assets': [
                {
                  'name': 'atv-launcher-armeabi-v7a-debug.apk',
                  'browser_download_url': 'https://example.com/debug.apk',
                  'size': 123,
                  'download_count': 10,
                  'content_type': 'application/vnd.android.package-archive',
                },
              ],
            },
          );
          response.write(jsonEncode(debugReleases));
        } else if (page == 2) {
          response.write(jsonEncode([
            {
              'tag_name': 'v2024.11.001-release',
              'name': 'ATV Launcher Release v2024.11.001',
              'html_url': 'https://example.com/release',
              'published_at': '2026-04-29T10:00:00Z',
              'body': officialMarker,
              'assets': [
                {
                  'name': 'atv-launcher-armeabi-v7a-release.apk',
                  'browser_download_url': 'https://example.com/release.apk',
                  'size': 456,
                  'download_count': 2,
                  'content_type': 'application/vnd.android.package-archive',
                },
              ],
            },
          ]));
        } else {
          response.write(jsonEncode(const <dynamic>[]));
        }
        await response.close();
      });

      final client = LauncherUpdateClient(
        releasesBaseUri: Uri.parse(
          'http://127.0.0.1:${server.port}/repos/xfire0392-netizen/atv-launcher/releases',
        ),
      );

      final release = await client.fetchLatestOfficialRelease();

      expect(release?.tagName, 'v2024.11.001-release');
      expect(requestedPages, ['1', '2']);
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
