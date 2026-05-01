import 'package:flauncher/flauncher_channel.dart';
import 'dart:async';
import 'dart:io';

import 'package:flauncher/launcher_update_client.dart';
import 'package:flauncher/providers/launcher_update_session.dart';
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
    final session = LauncherUpdateSession(
      updateClient: _FakeLauncherUpdateClient(release: release),
      launcherChannel: _FakeFLauncherChannel(
        liteStatus: const <String, dynamic>{},
        supportedAbis: const ['armeabi-v7a'],
      ),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(updateSession: session),
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
    expect(
        find.text(
          'Official release ready: ATV Launcher Release',
          skipOffstage: false,
        ),
        findsOneWidget);
    expect(find.text('4/29/2026 21:30', skipOffstage: false), findsOneWidget);
    expect(find.text('12 MB', skipOffstage: false), findsWidgets);
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        contains('update_panel_status_section'));
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
    final session = LauncherUpdateSession(
      updateClient: _FakeLauncherUpdateClient(release: null),
      launcherChannel: _FakeFLauncherChannel(
        liteStatus: const <String, dynamic>{},
        supportedAbis: const ['armeabi-v7a'],
      ),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(updateSession: session),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);

    expect(
      find.text(
        'No suitable official release is available right now.',
        skipOffstage: false,
      ),
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
    final session = LauncherUpdateSession(
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
      launcherChannel: _FakeFLauncherChannel(
        liteStatus: const <String, dynamic>{},
        supportedAbis: const ['armeabi-v7a'],
      ),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(updateSession: session),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);
    await tester.ensureVisible(find.text('Download latest official APK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download latest official APK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('atv-launcher-release.apk', skipOffstage: false),
      findsWidgets,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('update_panel_status_section'),
    );

    completer.complete();
    await _pumpUi(tester);
  });

  testWidgets(
      'arm64 device shows arm64 asset details and binds the download card to arm64',
      (tester) async {
    _prepareView(tester);
    final tempDirectory = await _createTempTestDirectory('update-panel-arm64');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);
    PackageInfo.setMockInitialValues(
      appName: 'ATV Launcher',
      packageName: 'com.atv.launcher',
      version: '2026.05.006',
      buildNumber: '21',
      buildSignature: 'release',
      installerStore: 'adb',
    );

    final bridgeService = _createBridgeService(
      canRequestPackageInstalls: true,
      adbEnabled: true,
    );
    addTearDown(bridgeService.dispose);

    final downloadedAssets = <String>[];
    final release = LauncherUpdateRelease(
      tagName: 'v2026.05.007-release',
      name: 'ATV Launcher Release',
      htmlUrl: 'https://example.com/release',
      publishedAt: DateTime(2026, 5, 1, 8, 0),
      body: '',
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
    final session = LauncherUpdateSession(
      updateClient: _FakeLauncherUpdateClient(
        release: release,
        onDownload: ({
          required asset,
          required destinationFile,
          required onProgress,
        }) async {
          downloadedAssets.add(asset.name);
          await destinationFile.writeAsString('apk');
          return LauncherDownloadedApk(
            fileName: asset.name,
            filePath: destinationFile.path,
          );
        },
      ),
      launcherChannel: _FakeFLauncherChannel(
        liteStatus: const <String, dynamic>{},
        supportedAbis: const ['arm64-v8a'],
      ),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(updateSession: session),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);

    final downloadCard = tester.widget<SettingsActionCard>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsActionCard &&
            widget.title == 'Download latest official APK',
      ),
    );
    expect(downloadCard.subtitle, startsWith('13 MB |'));
    expect(downloadCard.onPressed, isNotNull);
    expect(
      find.textContaining('atv-launcher-arm64-v8a-release.apk'),
      findsOneWidget,
    );
    expect(downloadedAssets, isEmpty);
  });

  testWidgets('v7a device keeps v7a asset in update panel', (tester) async {
    _prepareView(tester);
    final tempDirectory = await _createTempTestDirectory('update-panel-v7a');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);
    PackageInfo.setMockInitialValues(
      appName: 'ATV Launcher',
      packageName: 'com.atv.launcher',
      version: '2026.05.006',
      buildNumber: '21',
      buildSignature: 'release',
      installerStore: 'adb',
    );

    final bridgeService = _createBridgeService(
      canRequestPackageInstalls: true,
      adbEnabled: true,
    );
    addTearDown(bridgeService.dispose);

    final release = LauncherUpdateRelease(
      tagName: 'v2026.05.007-release',
      name: 'ATV Launcher Release',
      htmlUrl: 'https://example.com/release',
      publishedAt: DateTime(2026, 5, 1, 8, 0),
      body: '',
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
    final session = LauncherUpdateSession(
      updateClient: _FakeLauncherUpdateClient(release: release),
      launcherChannel: _FakeFLauncherChannel(
        liteStatus: const <String, dynamic>{},
        supportedAbis: const ['armeabi-v7a'],
      ),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(updateSession: session),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);

    final downloadCard = tester.widget<SettingsActionCard>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SettingsActionCard &&
            widget.title == 'Download latest official APK',
      ),
    );
    expect(downloadCard.subtitle, startsWith('12 MB |'));
    expect(
      find.textContaining('atv-launcher-armeabi-v7a-release.apk'),
      findsOneWidget,
    );
  });

  testWidgets('degraded ABI lookup shows a fallback warning in update panel',
      (tester) async {
    _prepareView(tester);
    final tempDirectory =
        await _createTempTestDirectory('update-panel-abi-fallback');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);
    PackageInfo.setMockInitialValues(
      appName: 'ATV Launcher',
      packageName: 'com.atv.launcher',
      version: '2026.05.006',
      buildNumber: '21',
      buildSignature: 'release',
      installerStore: 'adb',
    );

    final bridgeService = _createBridgeService(
      canRequestPackageInstalls: true,
      adbEnabled: true,
    );
    addTearDown(bridgeService.dispose);

    final release = LauncherUpdateRelease(
      tagName: 'v2026.05.007-release',
      name: 'ATV Launcher Release',
      htmlUrl: 'https://example.com/release',
      publishedAt: DateTime(2026, 5, 1, 8, 0),
      body: '',
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
    final session = LauncherUpdateSession(
      updateClient: _FakeLauncherUpdateClient(release: release),
      launcherChannel: _SequencedAbiLookupChannel(
        responses: [StateError('unsupported platform'), StateError('retry')],
      ),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(updateSession: session),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);

    expect(find.text('ABI fallback', skipOffstage: false), findsWidgets);
    expect(
      find.textContaining('generic APK fallback', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'atv-launcher-armeabi-v7a-release.apk',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  test('arm64 session downloads the arm64 asset selected for the device',
      () async {
    final tempDirectory =
        await _createTempTestDirectory('update-session-arm64');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });
    _installFakeTempPath(tempDirectory.path);

    final localizations =
        await AppLocalizations.delegate.load(const Locale('en'));
    final downloadedAssets = <String>[];
    final release = LauncherUpdateRelease(
      tagName: 'v2026.05.007-release',
      name: 'ATV Launcher Release',
      htmlUrl: 'https://example.com/release',
      publishedAt: DateTime(2026, 5, 1, 8, 0),
      body: '',
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
    final session = LauncherUpdateSession(
      updateClient: _FakeLauncherUpdateClient(
        release: release,
        onDownload: ({
          required asset,
          required destinationFile,
          required onProgress,
        }) async {
          downloadedAssets.add(asset.name);
          await destinationFile.writeAsString('apk');
          return LauncherDownloadedApk(
            fileName: asset.name,
            filePath: destinationFile.path,
          );
        },
      ),
      launcherChannel: _FakeFLauncherChannel(
        liteStatus: const <String, dynamic>{},
        supportedAbis: const ['arm64-v8a'],
      ),
    );
    addTearDown(session.dispose);

    await session.initialize();
    await session.checkLatestRelease(localizations);

    final selectedAsset = session.latestReleaseAsset;
    expect(selectedAsset?.name, 'atv-launcher-arm64-v8a-release.apk');

    await session.downloadLatestApk(selectedAsset!, localizations);

    expect(downloadedAssets, ['atv-launcher-arm64-v8a-release.apk']);
    expect(session.downloadedAssetName, 'atv-launcher-arm64-v8a-release.apk');
  });

  testWidgets('update action cards keep uniform size for a compact grid',
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
          locale: const Locale('vi'),
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

    Size sizeForTitle(String title) => tester.getSize(
          find.ancestor(
            of: find.text(title),
            matching: find.byType(SettingsFocusFrame),
          ),
        );

    final checkSize = sizeForTitle('Kiểm tra bản chính thức mới nhất');
    final downloadSize = sizeForTitle('Tải APK chính thức mới nhất');
    final installSize = sizeForTitle('Cài APK đã tải');
    final cleanupSize = sizeForTitle('Dọn APK đã tải');

    expect(checkSize.width, equals(downloadSize.width));
    expect(checkSize.width, equals(installSize.width));
    expect(checkSize.width, equals(cleanupSize.width));
    expect(checkSize.height, equals(downloadSize.height));
    expect(checkSize.height, equals(installSize.height));
    expect(checkSize.height, equals(cleanupSize.height));
  });

  testWidgets(
      'failed re-check clears stale release details instead of keeping the old release card',
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
      version: '2026.05.002',
      buildNumber: '17',
      buildSignature: 'release',
      installerStore: 'adb',
    );

    final bridgeService = _createBridgeService(
      canRequestPackageInstalls: true,
      adbEnabled: true,
    );
    addTearDown(bridgeService.dispose);

    final client = _SequencedFakeLauncherUpdateClient(
      responses: [
        LauncherUpdateRelease(
          tagName: 'v2026.05.001-release',
          name: 'Official Build 001',
          htmlUrl: 'https://example.com/release-001',
          publishedAt: DateTime(2026, 5, 1, 1, 20),
          body: 'Release notes',
          isDraft: false,
          isPrerelease: false,
          assets: [
            LauncherUpdateAsset(
              name: 'atv-launcher-armeabi-v7a-release.apk',
              browserDownloadUrl: 'https://example.com/release-001.apk',
              sizeBytes: 12582912,
              downloadCount: 1,
              contentType: 'application/vnd.android.package-archive',
              uploadedAt: DateTime(2026, 5, 1, 1, 22),
            ),
          ],
        ),
        StateError('offline'),
      ],
    );
    final session = LauncherUpdateSession(
      updateClient: client,
      launcherChannel: _FakeFLauncherChannel(
        liteStatus: const <String, dynamic>{},
        supportedAbis: const ['armeabi-v7a'],
      ),
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SystemBridgeService>.value(
        value: bridgeService,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdatePanelPage(updateSession: session),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);
    expect(
      find.text('Official Build 001', skipOffstage: false),
      findsWidgets,
    );

    await tester
        .ensureVisible(find.text('Check latest official release').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check latest official release'));
    await _pumpUi(tester);

    expect(find.text('Official Build 001'), findsNothing);
    expect(
      find.textContaining(
          'GitHub official release check failed: Bad state: offline'),
      findsOneWidget,
    );
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

class _SequencedFakeLauncherUpdateClient extends LauncherUpdateClient {
  final List<Object?> responses;
  int _callCount = 0;

  _SequencedFakeLauncherUpdateClient({
    required this.responses,
  });

  @override
  Future<LauncherUpdateRelease?> fetchLatestOfficialRelease() async {
    final index =
        _callCount < responses.length ? _callCount : responses.length - 1;
    _callCount += 1;
    final value = responses[index];
    if (value is LauncherUpdateRelease?) {
      return value;
    }
    if (value is Error) {
      throw value;
    }
    if (value is Exception) {
      throw value;
    }
    throw StateError(value.toString());
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
  final List<String> supportedAbis;

  _FakeFLauncherChannel({
    required this.liteStatus,
    this.supportedAbis = const <String>[],
  });

  @override
  Future<Map<String, dynamic>> getSystemBridgeStatusLite() async => liteStatus;

  @override
  Future<List<String>> getSupportedAbis() async => supportedAbis;

  @override
  StreamSubscription<dynamic> addSystemChangedListener(
    void Function(Map<String, dynamic>) listener,
  ) =>
      const Stream<dynamic>.empty().listen((_) {});
}

class _SequencedAbiLookupChannel extends FLauncherChannel {
  final List<Object> responses;
  int _callCount = 0;

  _SequencedAbiLookupChannel({required this.responses});

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

void _prepareView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
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
