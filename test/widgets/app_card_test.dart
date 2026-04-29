import 'dart:typed_data';

import 'package:flauncher/app_image_cache_invalidator.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  testWidgets('reloads the image on the first cache invalidation event',
      (tester) async {
    final settingsService = await _createSettingsService();
    final appsService = MockAppsService();
    final application = fakeApp(
      packageName: 'cache.test.first.invalidation',
      name: 'Cache Test',
    );
    final category = fakeCategory()..applications.add(application);

    when(appsService.getAppBanner(application.packageName))
        .thenAnswer((_) async => Uint8List.fromList(kTransparentImage));
    when(appsService.addListener(any)).thenReturn(null);
    when(appsService.removeListener(any)).thenReturn(null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProfileSecurityService?>.value(value: null),
          ListenableProvider<AppsService>.value(value: appsService),
          ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: AppCard(
                application: application,
                category: category,
                autofocus: true,
                onMove: (_) {},
                onMoveEnd: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    AppImageCacheInvalidator.instance.invalidate(application.packageName);
    await tester.pump();
    await tester.pumpAndSettle();

    verify(appsService.getAppBanner(application.packageName)).called(2);
  });
}

Future<SettingsService> _createSettingsService() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SettingsService(await SharedPreferences.getInstance());
}
