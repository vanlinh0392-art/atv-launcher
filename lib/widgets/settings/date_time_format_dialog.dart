/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tuple/tuple.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../date_time_widget.dart';
import '../ensure_visible.dart';

class DateTimeFormatDialog extends StatefulWidget {
  final String _initialDateFormat;
  final String _initialTimeFormat;

  const DateTimeFormatDialog(
    String initialDateFormat,
    String initialTimeFormat, {
    super.key,
  })  : _initialDateFormat = initialDateFormat,
        _initialTimeFormat = initialTimeFormat;

  @override
  State<DateTimeFormatDialog> createState() => _DateTimeFormatDialogState();
}

class _DateTimeFormatDialogState extends State<DateTimeFormatDialog> {
  late String _currentDateFormat;
  late String _currentTimeFormat;
  bool _isCustomExpanded = false;

  late final TextEditingController _customDateController;
  late final TextEditingController _customTimeController;

  final FocusNode _cancelFocusNode = FocusNode(debugLabel: 'format_dialog_cancel');
  final FocusNode _applyFocusNode = FocusNode(debugLabel: 'format_dialog_apply');
  final FocusNode _customToggleFocusNode =
      FocusNode(debugLabel: 'format_dialog_custom_toggle');
  final FocusNode _customDateFocusNode =
      FocusNode(debugLabel: 'format_dialog_custom_date');
  final FocusNode _customTimeFocusNode =
      FocusNode(debugLabel: 'format_dialog_custom_time');

  static const List<({String pattern, String label})> _datePresets = [
    (pattern: "Thứ 5 ngày d/M/y", label: "Thứ, ngày (d/M/y)"),
    (pattern: "Thứ 5 ngày d-M-y", label: "Thứ, ngày (d-M-y)"),
    (pattern: "E d/M", label: "Rút gọn (Th 5 3/9)"),
    (pattern: "d/M/y", label: "Ngày/Tháng (3/9/2026)"),
    (pattern: "dd-MM-yyyy", label: "Gạch ngang (03-09-2026)"),
    (pattern: "yyyy-MM-dd", label: "Chuẩn ISO (2026-09-03)"),
  ];

  static const List<({String pattern, String label})> _timePresets = [
    (pattern: "H:mm", label: "24 giờ (14:30)"),
    (pattern: "h:mm a", label: "12 giờ (02:30 PM)"),
    (pattern: "H:mm:ss", label: "Kèm giây (14:30:45)"),
  ];

  static const List<({String token, String desc})> _dateSpecifiers = [
    (token: "d", desc: "Ngày (3)"),
    (token: "dd", desc: "Ngày (03)"),
    (token: "M", desc: "Tháng (9)"),
    (token: "MM", desc: "Tháng (09)"),
    (token: "y", desc: "Năm (2026)"),
    (token: "E", desc: "Thứ (Th 5)"),
    (token: "EEEE", desc: "Thứ (Thứ Năm)"),
    (token: "/", desc: "Gạch /"),
    (token: "-", desc: "Gạch -"),
    (token: " ", desc: "Khoảng trắng"),
  ];

  static const List<({String token, String desc})> _timeSpecifiers = [
    (token: "H", desc: "Giờ 24h (14)"),
    (token: "HH", desc: "Giờ (14)"),
    (token: "h", desc: "Giờ 12h (2)"),
    (token: "hh", desc: "Giờ (02)"),
    (token: "m", desc: "Phút (30)"),
    (token: "mm", desc: "Phút (30)"),
    (token: "s", desc: "Giây"),
    (token: "a", desc: "AM/PM"),
    (token: ":", desc: "Dấu :"),
  ];

  @override
  void initState() {
    super.initState();
    _currentDateFormat = widget._initialDateFormat.trim().isEmpty
        ? "E d/M"
        : widget._initialDateFormat.trim();
    _currentTimeFormat = widget._initialTimeFormat.trim().isEmpty
        ? "H:mm"
        : widget._initialTimeFormat.trim();

    _customDateController = TextEditingController(text: _currentDateFormat);
    _customTimeController = TextEditingController(text: _currentTimeFormat);
  }

  @override
  void dispose() {
    _customDateController.dispose();
    _customTimeController.dispose();
    _cancelFocusNode.dispose();
    _applyFocusNode.dispose();
    _customToggleFocusNode.dispose();
    _customDateFocusNode.dispose();
    _customTimeFocusNode.dispose();
    super.dispose();
  }

  static String _safeFormatDate(DateTime dt, String pattern, String locale) {
    final trimmed = pattern.trim();
    if (trimmed.isEmpty) return DateFormat('d/M/y', locale).format(dt);
    if (DateTimeWidget.isVietnameseCustomFormat(trimmed)) {
      return DateTimeWidget.formatVietnameseDate(dt, trimmed);
    }
    try {
      return DateFormat(trimmed, locale).format(dt);
    } catch (_) {
      return DateFormat('d/M/y', locale).format(dt);
    }
  }

  static String _safeFormatTime(DateTime dt, String pattern, String locale) {
    final trimmed = pattern.trim();
    if (trimmed.isEmpty) return DateFormat('H:mm', locale).format(dt);
    try {
      return DateFormat(trimmed, locale).format(dt);
    } catch (_) {
      return DateFormat('H:mm', locale).format(dt);
    }
  }

  void _applyChanges() {
    final finalDate = _currentDateFormat.trim();
    final finalTime = _currentTimeFormat.trim();
    if (finalDate.isNotEmpty && finalTime.isNotEmpty) {
      Navigator.pop(context, Tuple2(finalDate, finalTime));
    } else {
      Navigator.pop(context);
    }
  }

  void _appendDateToken(String token) {
    setState(() {
      _currentDateFormat = (_currentDateFormat + token).trim();
      if (_currentDateFormat.length > 36) {
        _currentDateFormat = _currentDateFormat.substring(0, 36);
      }
      _customDateController.text = _currentDateFormat;
    });
  }

  void _appendTimeToken(String token) {
    setState(() {
      _currentTimeFormat = (_currentTimeFormat + token).trim();
      if (_currentTimeFormat.length > 36) {
        _currentTimeFormat = _currentTimeFormat.substring(0, 36);
      }
      _customTimeController.text = _currentTimeFormat;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final locale =
        Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? Platform.localeName;
    final now = DateTime.now();

    final activeDatePreset = _datePresets.any((p) => p.pattern == _currentDateFormat)
        ? _currentDateFormat
        : _datePresets.first.pattern;

    return Dialog(
      backgroundColor: const Color(0xFF151C26),
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2C3E55), width: 1.5),
      ),
      child: SizedBox(
        width: 720,
        height: 550,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule_outlined,
                      color: Color(0xFF00E5FF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations.dateAndTimeFormat,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFFF5F8FF),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Live Preview Box (RepaintBoundary - 60fps)
              RepaintBoundary(
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D141E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF23354A), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined,
                          size: 18, color: Colors.white54),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _safeFormatDate(now, _currentDateFormat, locale),
                          style: const TextStyle(
                            color: Color(0xFFF5F8FF),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _safeFormatTime(now, _currentTimeFormat, locale),
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Scrollable Presets Section (Top-First)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Presets Ngày (Top-First)
                      const Text(
                        'Định dạng ngày (Bấm chọn nhanh)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _datePresets.map((preset) {
                          final isSelected =
                              _currentDateFormat == preset.pattern;
                          final isAutoFocusTarget =
                              preset.pattern == activeDatePreset;
                          return _TvPresetChip(
                            key: ValueKey('date_preset_${preset.pattern}'),
                            label: preset.label,
                            sample: _safeFormatDate(now, preset.pattern, locale),
                            selected: isSelected,
                            autofocus: isAutoFocusTarget,
                            onSelected: () {
                              setState(() {
                                _currentDateFormat = preset.pattern;
                                _customDateController.text = preset.pattern;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Section 2: Presets Giờ (Top-First)
                      const Text(
                        'Định dạng giờ (Bấm chọn nhanh)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _timePresets.map((preset) {
                          final isSelected =
                              _currentTimeFormat == preset.pattern;
                          return _TvPresetChip(
                            key: ValueKey('time_preset_${preset.pattern}'),
                            label: preset.label,
                            sample: _safeFormatTime(now, preset.pattern, locale),
                            selected: isSelected,
                            autofocus: false,
                            onSelected: () {
                              setState(() {
                                _currentTimeFormat = preset.pattern;
                                _customTimeController.text = preset.pattern;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Section 3: Tùy chỉnh & Chèn ký hiệu (Collapsible - Không nuốt D-pad)
                      InkWell(
                        focusNode: _customToggleFocusNode,
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setState(() {
                            _isCustomExpanded = !_isCustomExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isCustomExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _isCustomExpanded
                                      ? 'Đóng tùy chỉnh thủ công'
                                      : 'Tùy chỉnh định dạng thủ công (Nhập tay)',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isCustomExpanded) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ký hiệu ngày
                              const Text(
                                'Bấm chèn nhanh ký hiệu ngày:',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _dateSpecifiers.map((spec) {
                                  return _SpecifierChip(
                                    label: '[${spec.token}]',
                                    description: spec.desc,
                                    onTap: () => _appendDateToken(spec.token),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                focusNode: _customDateFocusNode,
                                controller: _customDateController,
                                autofocus: false,
                                maxLength: 36,
                                decoration: InputDecoration(
                                  labelText: 'Chuỗi định dạng ngày tùy chỉnh',
                                  labelStyle:
                                      const TextStyle(color: Colors.white60),
                                  counterText: '',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _currentDateFormat = '';
                                        _customDateController.text = '';
                                      });
                                    },
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (val) {
                                  setState(() {
                                    _currentDateFormat = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),

                              // Ký hiệu giờ
                              const Text(
                                'Bấm chèn nhanh ký hiệu giờ:',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _timeSpecifiers.map((spec) {
                                  return _SpecifierChip(
                                    label: '[${spec.token}]',
                                    description: spec.desc,
                                    onTap: () => _appendTimeToken(spec.token),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                focusNode: _customTimeFocusNode,
                                controller: _customTimeController,
                                autofocus: false,
                                maxLength: 36,
                                decoration: InputDecoration(
                                  labelText: 'Chuỗi định dạng giờ tùy chỉnh',
                                  labelStyle:
                                      const TextStyle(color: Colors.white60),
                                  counterText: '',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _currentTimeFormat = '';
                                        _customTimeController.text = '';
                                      });
                                    },
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (val) {
                                  setState(() {
                                    _currentTimeFormat = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action Buttons Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('format_dialog_cancel_button'),
                    focusNode: _cancelFocusNode,
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text(localizations.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    key: const Key('format_dialog_apply_button'),
                    focusNode: _applyFocusNode,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Áp dụng'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A1017),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _applyChanges,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvPresetChip extends StatefulWidget {
  final String label;
  final String sample;
  final bool selected;
  final bool autofocus;
  final VoidCallback onSelected;

  const _TvPresetChip({
    super.key,
    required this.label,
    required this.sample,
    required this.selected,
    required this.autofocus,
    required this.onSelected,
  });

  @override
  State<_TvPresetChip> createState() => _TvPresetChipState();
}

class _TvPresetChipState extends State<_TvPresetChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final border = _isFocused
        ? Border.all(color: const Color(0xFF00E5FF), width: 2.0)
        : (widget.selected
            ? Border.all(color: const Color(0xFF7BE0A5), width: 1.5)
            : Border.all(color: Colors.white24, width: 1.0));

    final bgColor = widget.selected
        ? const Color(0xFF142C44)
        : (_isFocused ? const Color(0xFF1E2F42) : const Color(0xFF0F1722));

    return EnsureVisible(
      alignment: 0.2,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onShowFocusHighlight: (focused) {
          if (_isFocused != focused) {
            setState(() {
              _isFocused = focused;
            });
          }
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onSelected(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSelected,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: _isFocused
                ? (Matrix4.identity()..scale(1.04, 1.04))
                : Matrix4.identity(),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: border,
              boxShadow: _isFocused
                  ? const [
                      BoxShadow(
                        color: Color(0x6600E5FF),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.selected) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF7BE0A5),
                  ),
                  const SizedBox(width: 8),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.selected
                            ? const Color(0xFFF5F8FF)
                            : (_isFocused ? Colors.white : Colors.white70),
                        fontSize: 13,
                        fontWeight:
                            widget.selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.sample,
                      style: TextStyle(
                        color: widget.selected
                            ? const Color(0xFF7BE0A5)
                            : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecifierChip extends StatefulWidget {
  final String label;
  final String description;
  final VoidCallback onTap;

  const _SpecifierChip({
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  State<_SpecifierChip> createState() => _SpecifierChipState();
}

class _SpecifierChipState extends State<_SpecifierChip> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return EnsureVisible(
      alignment: 0.2,
      child: FocusableActionDetector(
        onShowFocusHighlight: (focused) {
          if (_isFocused != focused) {
            setState(() {
              _isFocused = focused;
            });
          }
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _isFocused
                  ? const Color(0xFF1E2F42)
                  : const Color(0xFF0D141E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isFocused ? const Color(0xFF00E5FF) : Colors.white24,
                width: _isFocused ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    color: _isFocused ? const Color(0xFF00E5FF) : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
