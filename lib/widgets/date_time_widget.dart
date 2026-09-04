/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimeWidget extends StatefulWidget {
  final Duration? updateInterval;
  final String _dateTimeFormatString;
  final TextStyle? textStyle;

  const DateTimeWidget(String dateTimeFormatString,
      {super.key, this.updateInterval, this.textStyle})
      : _dateTimeFormatString = dateTimeFormatString;

  static bool isVietnameseCustomFormat(String pattern) {
    final lower = pattern.toLowerCase();
    return lower.contains('thứ 5') ||
        lower.contains('thứ') ||
        lower.contains('ngày') ||
        lower.startsWith('vn_full');
  }

  static String formatVietnameseDate(DateTime dt, String pattern) {
    final w = dt.weekday == 7 ? 'Chủ nhật' : 'Thứ ${dt.weekday + 1}';
    final sep = pattern.contains('-') ? '-' : '/';
    return '$w ngày ${dt.day}$sep${dt.month}$sep${dt.year}';
  }

  @override
  State<DateTimeWidget> createState() => _DateTimeWidgetState();
}

class _DateTimeWidgetState extends State<DateTimeWidget>
    with WidgetsBindingObserver {
  late DateFormat _dateFormat;
  late DateTime _now;
  Timer? _timer;
  late String _formattedNow;
  late String _localeName;
  late String _formatPattern;

  String _formatDateTime(DateTime dt) {
    if (DateTimeWidget.isVietnameseCustomFormat(_formatPattern)) {
      return DateTimeWidget.formatVietnameseDate(dt, _formatPattern);
    }
    try {
      return _dateFormat.format(dt);
    } catch (_) {
      return DateFormat('E d/M', _localeName).format(dt);
    }
  }

  void _initDateFormatSafe() {
    if (DateTimeWidget.isVietnameseCustomFormat(_formatPattern)) {
      _dateFormat = DateFormat('d/M/y', _localeName);
    } else {
      try {
        _dateFormat = DateFormat(_formatPattern, _localeName);
      } catch (_) {
        _dateFormat = DateFormat('E d/M', _localeName);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _now = DateTime.now();
    _localeName = Platform.localeName;
    _formatPattern = widget._dateTimeFormatString;
    _initDateFormatSafe();
    _formattedNow = _formatDateTime(_now);
    _scheduleNextRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDateFormat();
  }

  @override
  void didUpdateWidget(covariant DateTimeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._dateTimeFormatString != widget._dateTimeFormatString ||
        oldWidget.updateInterval != widget.updateInterval) {
      _syncDateFormat(forceReschedule: true);
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final formattedNow = _formatDateTime(now);
      if (mounted) {
        setState(() {
          _now = now;
          _formattedNow = formattedNow;
        });
      }
      _scheduleNextRefresh();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(_formattedNow, style: widget.textStyle);

  void _refreshTime() {
    final now = DateTime.now();
    final formattedNow = _formatDateTime(now);
    if (formattedNow == _formattedNow) {
      _now = now;
      _scheduleNextRefresh();
      return;
    }
    setState(() {
      _now = now;
      _formattedNow = formattedNow;
    });
    _scheduleNextRefresh();
  }

  void _scheduleNextRefresh() {
    _timer?.cancel();
    _timer = Timer(_resolveUpdateInterval(), _refreshTime);
  }

  void _syncDateFormat({bool forceReschedule = false}) {
    final localeName =
        Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? Platform.localeName;
    final formatPattern = widget._dateTimeFormatString;
    final shouldRebuildFormat =
        _localeName != localeName || _formatPattern != formatPattern;
    if (!shouldRebuildFormat && !forceReschedule) {
      return;
    }
    _localeName = localeName;
    _formatPattern = formatPattern;
    _now = DateTime.now();
    _initDateFormatSafe();
    _formattedNow = _formatDateTime(_now);
    _scheduleNextRefresh();
  }

  Duration _resolveUpdateInterval() {
    final explicitInterval = widget.updateInterval;
    if (explicitInterval != null) {
      return explicitInterval;
    }
    final now = DateTime.now();
    if (_dateTimeFormatHasSeconds(widget._dateTimeFormatString)) {
      return Duration(milliseconds: 1000 - now.millisecond);
    }
    return Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
  }

  bool _dateTimeFormatHasSeconds(String format) {
    var quoted = false;
    for (var index = 0; index < format.length; index += 1) {
      final char = format[index];
      if (char == "'") {
        quoted = !quoted;
      } else if (!quoted && char == 's') {
        return true;
      }
    }
    return false;
  }
}
