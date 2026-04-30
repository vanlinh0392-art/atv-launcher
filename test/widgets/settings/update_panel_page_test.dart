import 'package:flauncher/flauncher_channel.dart';
import 'dart:async';
import 'dart:io';

import 'package:flauncher/launcher_update_client.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flauncher/widgets/settings/update_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Provider.debugCheckInvalidValueType = null;
  });

  testWidgets(
      'update panel shows official release size, upload date and colored permission state',
      (tester) async {
    _prepareView(tester);
    final tempDirectory = await _createTempTestDirectory('update-panel');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);
    PackageInfo.setMockInitialValues(
      appName: 'ATV Launcher',
      packageName: 'com.atv.launcher',
      version: '2024.11.001',
      buildNumber: '15',
      buildSignature: 'debug',
      installerStore: 'adb',
    );

    final bridgeService = _createBridgeService(
      canRequestPackageInstalls: false,
      adbEnabled: true,
    );
    addTearDown(bridgeService.dispose);

    final release = LauncherUpdateRelease(
      tagName: 'v2026.04.12-release',
      name: 'ATV Launcher Release',
      htmlUrl:
          'https://github.com/xfire0392-netizen/atv-launcher/releases/tag/v2026.04.12-release',
      publishedAt: DateTime(2026, 4, 29, 20, 0),
      body: 'Release notes',
      isDraft: false,
      isPrerelease: false,
      assets: [
        LauncherUpdateAsset(
          name: 'atv-launcher-release.apk',
          browserDownloadUrl: 'https://example.com/atv-launcher-release.apk',
          sizeBytes: 12582912,
          downloadCount: 42,
          contentType: 'application/vnd.android.package-archive',
          uploadedAt: DateTime(2026, 4, 29, 21, 30),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(
              updateClient: _FakeLauncherUpdateClient(release: release),
            ),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    final permissionTile = tester.widget<SettingsMetricTile>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsMetricTile &&
            widget.label == 'Install permission',
      ),
    );
    expect(permissionTile.value, 'Needs approval');
    expect(permissionTile.accentColor, const Color(0xFFFFC970));

    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);
    expect(find.text('Official release ready: ATV Launcher Release'),
        findsOneWidget);
    expect(find.text('4/29/2026 21:30'), findsOneWidget);
    expect(find.text('12 MB'), findsWidgets);
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        contains('update_panel_release_details'));
  });

  testWidgets('shows no suitable official release when only debug builds exist',
      (tester) async {
    _prepareView(tester);
    final tempDirectory = await _createTempTestDirectory('update-panel');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);
    PackageInfo.setMockInitialValues(
      appName: 'ATV Launcher',
      packageName: 'com.atv.launcher',
      version: '2024.11.001',
      buildNumber: '15',
      buildSignature: 'debug',
      installerStore: 'adb',
    );

    final bridgeService = _createBridgeService(
      canRequestPackageInstalls: true,
      adbEnabled: true,
    );
    addTearDown(bridgeService.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(
              updateClient: _FakeLauncherUpdateClient(release: null),
            ),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);

    expect(
      find.text('No suitable official release is available right now.'),
      findsWidgets,
    );
    expect(
      tester
          .widget<SettingsActionCard>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is SettingsActionCard &&
                  widget.title == 'Download latest official APK',
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('shows download progress with file name and bytes',
      (tester) async {
    _prepareView(tester);
    final tempDirectory = await _createTempTestDirectory('update-panel');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);
    PackageInfo.setMockInitialValues(
      appName: 'ATV Launcher',
      packageName: 'com.atv.launcher',
      version: '2024.11.001',
      buildNumber: '15',
      buildSignature: 'debug',
      installerStore: 'adb',
    );

    final bridgeService = _createBridgeService(
      canRequestPackageInstalls: true,
      adbEnabled: true,
    );
    addTearDown(bridgeService.dispose);

    final release = LauncherUpdateRelease(
      tagName: 'v2026.04.12-release',
      name: 'ATV Launcher Release',
      htmlUrl: 'https://example.com/release',
      publishedAt: DateTime(2026, 4, 29, 20, 0),
      body: '',
      isDraft: false,
      isPrerelease: false,
      assets: [
        LauncherUpdateAsset(
          name: 'atv-launcher-release.apk',
          browserDownloadUrl: 'https://example.com/atv-launcher-release.apk',
          sizeBytes: 1024,
          downloadCount: 1,
          contentType: 'application/vnd.android.package-archive',
          uploadedAt: DateTime(2026, 4, 29, 21, 30),
        ),
      ],
    );
    final completer = Completer<void>();

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(
              updateClient: _FakeLauncherUpdateClient(
                release: release,
                onDownload: ({
                  required asset,
                  required destinationFile,
                  required onProgress,
                }) async {
                  onProgress(
                    LauncherUpdateDownloadProgress(
                      fileName: asset.name,
                      receivedBytes: 512,
                      totalBytes: 1024,
                    ),
                  );
                  await completer.future;
                  await destinationFile.writeAsString('apk');
                  return LauncherDownloadedApk(
                    fileName: asset.name,
                    filePath: destinationFile.path,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);
    await tester.tap(find.text('Download latest official APK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('atv-launcher-release.apk'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('update_panel_status_section'),
    );

    completer.complete();
    await _pumpUi(tester);
  });

}

class _FakeLauncherUpdateClient extends LauncherUpdateClient {
  final LauncherUpdateRelease? release;
  final Future<LauncherDownloadedApk> Function({
    required LauncherUpdateAsset asset,
    required File destinationFile,
    required void Function(LauncherUpdateDownloadProgress progress) onProgress,
  })? onDownload;

  _FakeLauncherUpdateClient({
    required this.release,
    this.onDownload,
  });

  @override
  Future<LauncherUpdateRelease?> fetchLatestOfficialRelease() async => release;

  @override
  Future<LauncherDownloadedApk> downloadApkAsset({
    required LauncherUpdateAsset asset,
    required File destinationFile,
    required void Function(LauncherUpdateDownloadProgress progress) onProgress,
  }) async {
    if (onDownload != null) {
      return onDownload!(
        asset: asset,
        destinationFile: destinationFile,
        onProgress: onProgress,
      );
    }
    await destinationFile.writeAsString('apk');
    return LauncherDownloadedApk(
      fileName: asset.name,
      filePath: destinationFile.path,
    );
  }
}

SystemBridgeService _createBridgeService({
  required bool canRequestPackageInstalls,
  required bool adbEnabled,
}) {
  final channel = _FakeFLauncherChannel(
    liteStatus: <String, dynamic>{
      'updates': <String, dynamic>{
        'canRequestPackageInstalls': canRequestPackageInstalls,
        'adbEnabled': adbEnabled,
      },
    },
  );
  return SystemBridgeService(channel);
}

class _FakeFLauncherChannel extends FLauncherChannel {
  final Map<String, dynamic> liteStatus;

  _FakeFLauncherChannel({
    required this.liteStatus,
  });

  @override
  Future<Map<String, dynamic>> getSystemBridgeStatusLite() async => liteStatus;

  @override
  StreamSubscription<dynamic> addSystemChangedListener(
    void Function(Map<String, dynamic>) listener,
  ) =>
      const Stream<dynamic>.empty().listen((_) {});
}

void _prepareView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
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
