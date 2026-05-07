import 'dart:io';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/launcher_update_client.dart';
import 'package:flauncher/providers/launcher_update_session.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retries ABI resolution on release check after degraded init', () async {
    final tempDirectory =
        await _createTempTestDirectory('launcher-update-session-retry');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);

    final session = LauncherUpdateSession(
      updateClient: _FakeLauncherUpdateClient(release: _officialRelease()),
      launcherChannel: _SequencedAbiFLauncherChannel(
        responses: [
          StateError('channel not ready'),
          StateError('channel still not ready'),
          const ['arm64-v8a'],
        ],
      ),
    );
    addTearDown(session.dispose);

    await session.initialize();

    expect(
      session.abiResolutionState,
      LauncherUpdateAbiResolutionState.degraded,
    );
    expect(session.deviceAbis, isEmpty);

    final localizations =
        await AppLocalizations.delegate.load(const Locale('en'));
    await session.checkLatestRelease(localizations);

    expect(
      session.abiResolutionState,
      LauncherUpdateAbiResolutionState.resolved,
    );
    expect(session.deviceAbis, const ['arm64-v8a']);
    expect(
      session.latestReleaseAsset?.name,
      'atv-launcher-arm64-v8a-release.apk',
    );
  });

  test('keeps a degraded updater state visible when ABI lookup keeps failing',
      () async {
    final tempDirectory =
        await _createTempTestDirectory('launcher-update-session-degraded');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);

    final session = LauncherUpdateSession(
      updateClient: _FakeLauncherUpdateClient(release: _officialRelease()),
      launcherChannel: _SequencedAbiFLauncherChannel(
        responses: [
          StateError('cold start failed'),
          StateError('retry failed'),
        ],
      ),
    );
    addTearDown(session.dispose);

    await session.initialize();

    final localizations =
        await AppLocalizations.delegate.load(const Locale('en'));
    await session.checkLatestRelease(localizations);

    expect(
      session.abiResolutionState,
      LauncherUpdateAbiResolutionState.degraded,
    );
    expect(
      session.latestReleaseAsset?.name,
      'atv-launcher-armeabi-v7a-release.apk',
    );
  });

  test('shows a specific message when the GitHub release repository is unavailable',
      () async {
    final tempDirectory =
        await _createTempTestDirectory('launcher-update-session-unavailable');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);

    final session = LauncherUpdateSession(
      updateClient: _FakeLauncherUpdateClient(
        error: LauncherUpdateRepositoryUnavailableException(
          statusCode: HttpStatus.notFound,
          uri: Uri.parse(
            'https://api.github.com/repos/example-owner/atv-launcher/releases',
          ),
        ),
      ),
      launcherChannel: _SequencedAbiFLauncherChannel(
        responses: const [
          ['arm64-v8a'],
        ],
      ),
    );
    addTearDown(session.dispose);

    await session.initialize();

    final localizations =
        await AppLocalizations.delegate.load(const Locale('vi'));
    await session.checkLatestRelease(localizations);

    expect(session.latestRelease, isNull);
    expect(session.lastMessage, contains('HTTP 404'));
    expect(session.lastMessage, contains('private'));
    expect(session.lastMessage, contains('suspend'));
  });
}

LauncherUpdateRelease _officialRelease() => LauncherUpdateRelease(
      tagName: 'v2026.05.007-release',
      name: 'ATV Launcher Release',
      htmlUrl: 'https://example.com/release',
      publishedAt: DateTime(2026, 5, 1, 8, 0),
      body: LauncherUpdateClient.officialChannelMarker,
      isDraft: false,
      isPrerelease: false,
      assets: [
        LauncherUpdateAsset(
          name: 'atv-launcher-armeabi-v7a-release.apk',
          browserDownloadUrl: 'https://example.com/v7a.apk',
          sizeBytes: 12 * 1024 * 1024,
          downloadCount: 40,
          contentType: 'application/vnd.android.package-archive',
          uploadedAt: DateTime(2026, 5, 1, 8, 5),
        ),
        LauncherUpdateAsset(
          name: 'atv-launcher-arm64-v8a-release.apk',
          browserDownloadUrl: 'https://example.com/v8a.apk',
          sizeBytes: 13 * 1024 * 1024,
          downloadCount: 20,
          contentType: 'application/vnd.android.package-archive',
          uploadedAt: DateTime(2026, 5, 1, 8, 10),
        ),
      ],
    );

class _FakeLauncherUpdateClient extends LauncherUpdateClient {
  final LauncherUpdateRelease? release;
  final Object? error;

  _FakeLauncherUpdateClient({this.release, this.error});

  @override
  Future<LauncherUpdateRelease?> fetchLatestOfficialRelease() async {
    final resolvedError = error;
    if (resolvedError != null) {
      if (resolvedError is Exception) {
        throw resolvedError;
      }
      if (resolvedError is Error) {
        throw resolvedError;
      }
      throw StateError(resolvedError.toString());
    }
    return release;
  }
}

class _SequencedAbiFLauncherChannel extends FLauncherChannel {
  final List<Object> responses;
  int _callCount = 0;

  _SequencedAbiFLauncherChannel({required this.responses});

  @override
  Future<List<String>> getSupportedAbis() async {
    final index =
        _callCount < responses.length ? _callCount : responses.length - 1;
    _callCount += 1;
    final response = responses[index];
    if (response is List<String>) {
      return response;
    }
    if (response is Error) {
      throw response;
    }
    if (response is Exception) {
      throw response;
    }
    throw StateError(response.toString());
  }
}

void _installFakeTempPath(String path) {
  final original = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _FakePathProviderPlatform(path);
  addTearDown(() {
    PathProviderPlatform.instance = original;
  });
}

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String temporaryPath;

  _FakePathProviderPlatform(this.temporaryPath);

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

Future<Directory> _createTempTestDirectory(String name) async {
  final directory = Directory(
    '${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}$name',
  );
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
  directory.createSync(recursive: true);
  return directory;
}
