import 'package:flauncher/widgets/settings/settings_perf_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds benchmark metrics from frame durations', () {
    final metrics = SettingsBenchmarkMetrics.fromFrameDurations(
      const <double>[8, 12, 18, 32, 48, 60],
    );

    expect(metrics.frameCount, 6);
    expect(metrics.p50, 32);
    expect(metrics.p90, 60);
    expect(metrics.p95, 60);
    expect(metrics.worstTotalFrameMs, 60);
    expect(metrics.slowFramesOver16, 4);
    expect(metrics.slowFramesOver33, 2);
    expect(metrics.slowFramesOver50, 1);
  });

  testWidgets('logs ready plus open and dpad summaries', (tester) async {
    final logs = <String>[];
    final probe = SettingsPerfProbe(
      sessionId: 'bench-42',
      route: 'home_layout_panel',
      logger: logs.add,
      dpadIdleDuration: const Duration(milliseconds: 1),
    );

    probe.markReady('home_layout_target_appLocale_option_1');
    probe.recordDpadSample(
      const SettingsBenchmarkDpadSample(
        key: 'DOWN',
        fromFocus: 'home_layout_target_appLocale_option_1',
        toFocus: 'home_layout_rows_preset',
        inputToSettledFrameMs: 19,
      ),
    );
    await tester.pump(const Duration(milliseconds: 2));
    probe.dispose();

    expect(
      logs.any(
        (line) =>
            line.contains('settings_benchmark_ready') &&
            line.contains('sessionId=bench-42'),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (line) =>
            line.contains('settings_benchmark_summary') &&
            line.contains('phase=open'),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (line) =>
            line.contains('settings_benchmark_summary') &&
            line.contains('phase=dpad') &&
            line.contains('sampleCount=1'),
      ),
      isTrue,
    );
  });
}
