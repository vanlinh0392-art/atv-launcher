import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/settings/density_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../mocks.mocks.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  void prepareView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpDensityPage(
    WidgetTester tester, {
    required MockSystemBridgeService bridgeService,
    FocusNode? primaryFocusNode,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChangeNotifierProvider<SystemBridgeService>.value(
            value: bridgeService,
            child: DensityPanelPage(
              primaryFocusNode: primaryFocusNode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'displays 4 preset DPI options, reset button, and no TextField exists',
      (tester) async {
    prepareView(tester);
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.densityStatus).thenReturn(const <String, dynamic>{
      'currentDensity': 320,
      'factoryDensity': 320,
      'overrideDensity': null,
      'executionPath': 'wm density',
    });

    await pumpDensityPage(tester, bridgeService: bridgeService);

    // Assert NO TextField exists anywhere in the widget tree
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('density_custom_input_field')), findsNothing);

    // Assert 4 Preset buttons are present
    expect(
      find.byKey(const ValueKey<String>('density_preset_option_240')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('density_preset_option_280')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('density_preset_option_320')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('density_preset_option_360')),
      findsOneWidget,
    );

    expect(find.text('240 (Nhỏ gọn)'), findsOneWidget);
    expect(find.text('280 (Cân đối)'), findsOneWidget);
    expect(find.text('320 (Tiêu chuẩn)'), findsAtLeastNWidgets(1));
    expect(find.text('360 (Lớn)'), findsOneWidget);

    // Assert Reset button is present
    expect(find.byKey(const Key('density_reset_button')), findsOneWidget);
    expect(find.text('Đặt lại DPI gốc'), findsOneWidget);
  });

  testWidgets(
      'navigates D-pad smoothly between presets and reset button without dropping focus',
      (tester) async {
    prepareView(tester);
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.densityStatus).thenReturn(const <String, dynamic>{
      'currentDensity': 240,
      'factoryDensity': 320,
      'overrideDensity': null,
    });

    await pumpDensityPage(tester, bridgeService: bridgeService);

    // Initially, option 240 (option_0) is focused
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('density_primary_apply_option_0'),
    );

    // D-pad Right -> 280 (option_1)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('density_primary_apply_option_1'),
    );

    // D-pad Right -> 320 (option_2)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('density_primary_apply_option_2'),
    );

    // D-pad Right -> 360 (option_3)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      contains('density_primary_apply_option_3'),
    );

    // D-pad Down -> Moves to Reset button
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      anyOf(
        contains('Đặt lại DPI gốc'),
        contains('Đặt_lại_DPI_gốc'),
      ),
    );

    // D-pad Up -> Moves back to preset selector row
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      anyOf(
        contains('density_primary_apply'),
        contains('density_preset_selector'),
      ),
    );

    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  testWidgets(
      'activating preset DPI calls bridgeService.applyDensity and shows 10s countdown safety dialog',
      (tester) async {
    prepareView(tester);
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.densityStatus).thenReturn(const <String, dynamic>{
      'currentDensity': 320,
      'factoryDensity': 320,
      'overrideDensity': null,
    });
    when(bridgeService.applyDensity(280)).thenAnswer(
      (_) async => const <String, dynamic>{
        'success': true,
        'message': 'Đã cập nhật DPI.',
      },
    );
    when(bridgeService.resetDensity()).thenAnswer(
      (_) async => const <String, dynamic>{
        'success': true,
        'message': 'Đã đặt lại DPI.',
      },
    );

    await pumpDensityPage(tester, bridgeService: bridgeService);

    await tester.tap(
      find.byKey(const ValueKey<String>('density_preset_option_280')),
    );
    await tester.pumpAndSettle();

    verify(bridgeService.applyDensity(280)).called(1);

    // Verify Safety Confirmation Dialog
    expect(find.text('Xác nhận mật độ DPI mới'), findsOneWidget);
    expect(find.textContaining('Đã áp dụng DPI 280'), findsOneWidget);
    expect(
      find.textContaining('Tự động hoàn tác sau 10 giây...'),
      findsOneWidget,
    );
    expect(find.text('Hoàn tác ngay (Khuyên dùng)'), findsOneWidget);
    expect(find.text('Giữ lại'), findsOneWidget);
  });

  testWidgets('safety dialog automatically reverts after countdown completes',
      (tester) async {
    prepareView(tester);
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.densityStatus).thenReturn(const <String, dynamic>{
      'currentDensity': 320,
      'factoryDensity': 320,
      'overrideDensity': null,
    });
    when(bridgeService.applyDensity(240)).thenAnswer(
      (_) async => const <String, dynamic>{
        'success': true,
        'message': 'Đã cập nhật DPI.',
      },
    );
    when(bridgeService.resetDensity()).thenAnswer(
      (_) async => const <String, dynamic>{
        'success': true,
        'message': 'Đã đặt lại DPI.',
      },
    );

    await pumpDensityPage(tester, bridgeService: bridgeService);

    await tester.tap(
      find.byKey(const ValueKey<String>('density_preset_option_240')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận mật độ DPI mới'), findsOneWidget);

    // Let the 10-second timer elapse
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();

    // Dialog should auto-close and trigger revert via resetDensity (as hadOverride was false)
    expect(find.text('Xác nhận mật độ DPI mới'), findsNothing);
    verify(bridgeService.resetDensity()).called(1);
  });

  testWidgets(
      'safety dialog reverts to previous override density when clicking Hoàn tác',
      (tester) async {
    prepareView(tester);
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.densityStatus).thenReturn(const <String, dynamic>{
      'currentDensity': 280,
      'factoryDensity': 320,
      'overrideDensity': 280,
    });
    when(bridgeService.applyDensity(360)).thenAnswer(
      (_) async => const <String, dynamic>{
        'success': true,
        'message': 'Đã cập nhật DPI.',
      },
    );
    when(bridgeService.applyDensity(280)).thenAnswer(
      (_) async => const <String, dynamic>{
        'success': true,
        'message': 'Đã cập nhật DPI.',
      },
    );

    await pumpDensityPage(tester, bridgeService: bridgeService);

    await tester.tap(
      find.byKey(const ValueKey<String>('density_preset_option_360')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận mật độ DPI mới'), findsOneWidget);

    // Click 'Hoàn tác ngay (Khuyên dùng)'
    await tester.tap(find.text('Hoàn tác ngay (Khuyên dùng)'));
    await tester.pumpAndSettle();

    // Dialog closed and reverted to previous override density (280)
    expect(find.text('Xác nhận mật độ DPI mới'), findsNothing);
    verify(bridgeService.applyDensity(280)).called(1);
  });

  testWidgets('clicking Reset button calls bridgeService.resetDensity()',
      (tester) async {
    prepareView(tester);
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.densityStatus).thenReturn(const <String, dynamic>{
      'currentDensity': 280,
      'factoryDensity': 320,
      'overrideDensity': 280,
    });
    when(bridgeService.resetDensity()).thenAnswer(
      (_) async => const <String, dynamic>{
        'success': true,
        'message': 'Đã đặt lại DPI.',
      },
    );

    await pumpDensityPage(tester, bridgeService: bridgeService);

    await tester.tap(find.byKey(const Key('density_reset_button')));
    await tester.pumpAndSettle();

    verify(bridgeService.resetDensity()).called(1);
    expect(find.text('Đã đặt lại DPI.'), findsOneWidget);
  });

  testWidgets(
      'displays custom DPI banner when current density is not in presets',
      (tester) async {
    prepareView(tester);
    final bridgeService = MockSystemBridgeService();
    when(bridgeService.densityStatus).thenReturn(const <String, dynamic>{
      'currentDensity': 300,
      'factoryDensity': 320,
      'overrideDensity': 300,
    });

    await pumpDensityPage(tester, bridgeService: bridgeService);

    expect(
      find.text('Đang dùng DPI tùy chỉnh: 300 DPI (Gốc: 320)'),
      findsOneWidget,
    );
  });
}
