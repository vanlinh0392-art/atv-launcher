import 'dart:async';
import 'dart:ui' show FrameTiming, TimingsCallback;

import 'package:flutter/widgets.dart';

class SettingsBenchmarkMetrics {
  final int frameCount;
  final double p50;
  final double p90;
  final double p95;
  final double worstTotalFrameMs;
  final int slowFramesOver16;
  final int slowFramesOver33;
  final int slowFramesOver50;

  const SettingsBenchmarkMetrics({
    required this.frameCount,
    required this.p50,
    required this.p90,
    required this.p95,
    required this.worstTotalFrameMs,
    required this.slowFramesOver16,
    required this.slowFramesOver33,
    required this.slowFramesOver50,
  });

  factory SettingsBenchmarkMetrics.empty() => const SettingsBenchmarkMetrics(
        frameCount: 0,
        p50: 0,
        p90: 0,
        p95: 0,
        worstTotalFrameMs: 0,
        slowFramesOver16: 0,
        slowFramesOver33: 0,
        slowFramesOver50: 0,
      );

  factory SettingsBenchmarkMetrics.fromFrameDurations(
    Iterable<double> totalFrameMs,
  ) {
    final samples = totalFrameMs
        .where((sample) => sample.isFinite && sample >= 0)
        .map((sample) => sample.toDouble())
        .toList(growable: false);
    if (samples.isEmpty) {
      return SettingsBenchmarkMetrics.empty();
    }
    final sorted = List<double>.of(samples)..sort();
    return SettingsBenchmarkMetrics(
      frameCount: samples.length,
      p50: _percentile(sorted, 0.50),
      p90: _percentile(sorted, 0.90),
      p95: _percentile(sorted, 0.95),
      worstTotalFrameMs: sorted.last,
      slowFramesOver16: samples.where((sample) => sample > 16.0).length,
      slowFramesOver33: samples.where((sample) => sample > 33.0).length,
      slowFramesOver50: samples.where((sample) => sample > 50.0).length,
    );
  }

  static double _percentile(List<double> sorted, double percentile) {
    if (sorted.isEmpty) {
      return 0;
    }
    final clamped = percentile.clamp(0.0, 1.0);
    final index = ((sorted.length - 1) * clamped).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

class SettingsBenchmarkDpadSample {
  final String key;
  final String fromFocus;
  final String toFocus;
  final int inputToSettledFrameMs;

  const SettingsBenchmarkDpadSample({
    required this.key,
    required this.fromFocus,
    required this.toFocus,
    required this.inputToSettledFrameMs,
  });
}

typedef SettingsPerfLogger = void Function(String message);

class SettingsPerfProbe {
  final String sessionId;
  final String route;
  final SettingsPerfLogger _logger;
  final Duration _openPhaseDuration;
  final Duration _dpadIdleDuration;

  final List<double> _openFrameDurations = <double>[];
  final List<double> _dpadFrameDurations = <double>[];
  TimingsCallback? _timingsCallback;
  Timer? _openPhaseTimer;
  Timer? _dpadIdleTimer;
  bool _readyLogged = false;
  bool _openSummaryLogged = false;
  bool _dpadPhaseStarted = false;
  bool _dpadSummaryLogged = false;
  int _dpadSampleCount = 0;

  SettingsPerfProbe({
    required this.sessionId,
    required this.route,
    required SettingsPerfLogger logger,
    Duration openPhaseDuration = const Duration(milliseconds: 1500),
    Duration dpadIdleDuration = const Duration(milliseconds: 600),
  })  : _logger = logger,
        _openPhaseDuration = openPhaseDuration,
        _dpadIdleDuration = dpadIdleDuration;

  void attach() {
    if (_timingsCallback != null) {
      return;
    }
    _timingsCallback = _handleTimings;
    WidgetsBinding.instance.addTimingsCallback(_timingsCallback!);
    _openPhaseTimer = Timer(_openPhaseDuration, finalizeOpenPhase);
  }

  void markReady(String focusLabel) {
    if (_readyLogged) {
      return;
    }
    _readyLogged = true;
    _emit(
      'settings_benchmark_ready '
      'sessionId=$sessionId route=$route focus=$focusLabel',
    );
  }

  void recordDpadSample(SettingsBenchmarkDpadSample sample) {
    if (!_openSummaryLogged) {
      finalizeOpenPhase();
    }
    _dpadPhaseStarted = true;
    _dpadSampleCount += 1;
    _emit(
      'settings_benchmark_dpad_sample '
      'sessionId=$sessionId '
      'route=$route '
      'key=${sample.key} '
      'fromFocus=${sample.fromFocus} '
      'toFocus=${sample.toFocus} '
      'inputToSettledFrameMs=${sample.inputToSettledFrameMs}',
    );
    _dpadIdleTimer?.cancel();
    _dpadIdleTimer = Timer(_dpadIdleDuration, finalizeDpadPhase);
  }

  void finalizeOpenPhase() {
    if (_openSummaryLogged) {
      return;
    }
    _openSummaryLogged = true;
    _openPhaseTimer?.cancel();
    _emitSummary(
      phase: 'open',
      metrics: SettingsBenchmarkMetrics.fromFrameDurations(_openFrameDurations),
    );
  }

  void finalizeDpadPhase() {
    if (_dpadSummaryLogged || !_dpadPhaseStarted) {
      return;
    }
    _dpadSummaryLogged = true;
    _dpadIdleTimer?.cancel();
    _emitSummary(
      phase: 'dpad',
      metrics: SettingsBenchmarkMetrics.fromFrameDurations(_dpadFrameDurations),
      sampleCount: _dpadSampleCount,
    );
  }

  void dispose() {
    _openPhaseTimer?.cancel();
    _dpadIdleTimer?.cancel();
    if (!_openSummaryLogged) {
      finalizeOpenPhase();
    }
    if (_dpadPhaseStarted && !_dpadSummaryLogged) {
      finalizeDpadPhase();
    }
    if (_timingsCallback != null) {
      WidgetsBinding.instance.removeTimingsCallback(_timingsCallback!);
      _timingsCallback = null;
    }
  }

  void _handleTimings(List<FrameTiming> timings) {
    final target = !_openSummaryLogged
        ? _openFrameDurations
        : (_dpadPhaseStarted && !_dpadSummaryLogged
            ? _dpadFrameDurations
            : null);
    if (target == null) {
      return;
    }
    target.addAll(
      timings.map(
        (timing) => timing.totalSpan.inMicroseconds / 1000.0,
      ),
    );
  }

  void _emitSummary({
    required String phase,
    required SettingsBenchmarkMetrics metrics,
    int? sampleCount,
  }) {
    final buffer = StringBuffer()
      ..write('settings_benchmark_summary ')
      ..write('sessionId=$sessionId ')
      ..write('route=$route ')
      ..write('phase=$phase ')
      ..write('frameCount=${metrics.frameCount} ')
      ..write('p50=${metrics.p50.toStringAsFixed(1)} ')
      ..write('p90=${metrics.p90.toStringAsFixed(1)} ')
      ..write('p95=${metrics.p95.toStringAsFixed(1)} ')
      ..write(
        'worstTotalFrameMs=${metrics.worstTotalFrameMs.toStringAsFixed(1)} ',
      )
      ..write('slowFramesOver16=${metrics.slowFramesOver16} ')
      ..write('slowFramesOver33=${metrics.slowFramesOver33} ')
      ..write('slowFramesOver50=${metrics.slowFramesOver50}');
    if (sampleCount != null) {
      buffer.write(' sampleCount=$sampleCount');
    }
    _emit(buffer.toString());
  }

  void _emit(String message) {
    _logger('FLauncherPerf $message');
  }
}
