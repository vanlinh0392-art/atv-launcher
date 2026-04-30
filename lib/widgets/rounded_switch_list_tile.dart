import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ensure_visible.dart';
import 'settings/settings_chrome.dart';
import 'settings/tv_controls.dart';

class RoundedSwitchListTile extends StatefulWidget {
  final bool value;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? debugLabel;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget secondary;

  const RoundedSwitchListTile(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.title,
      required this.secondary,
      this.autofocus = false,
      this.focusNode,
      this.debugLabel});

  @override
  State<RoundedSwitchListTile> createState() => _RoundedSwitchListTileState();
}

class _RoundedSwitchListTileState extends State<RoundedSwitchListTile> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _configureFocusNode();
  }

  @override
  void didUpdateWidget(covariant RoundedSwitchListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode &&
        oldWidget.debugLabel == widget.debugLabel) {
      return;
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    _configureFocusNode();
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: EnsureVisible.settingsAlignment,
        settleFrameCount: 1,
        preferImmediate: true,
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          canRequestFocus: widget.onChanged != null,
          onFocusChange: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
            }
          },
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            if (isSettingsActivateKey(event.logicalKey) &&
                widget.onChanged != null) {
              _toggleValue();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SettingsFocusFrame(
            padding: EdgeInsets.zero,
            variant: SettingsFocusFrameVariant.rowOnly,
            focusEmphasis: 1.28,
            focused: _focused,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onChanged == null ? null : _toggleValue,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 110),
                opacity:
                    widget.onChanged == null ? 0.46 : (_focused ? 1 : 0.97),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconTheme.merge(
                        data: IconThemeData(
                          color: widget.onChanged == null
                              ? Colors.white38
                              : (_focused ? Colors.white : Colors.white70),
                        ),
                        child: widget.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: widget.title),
                      const SizedBox(width: 8),
                      ExcludeFocus(
                        child: SizedBox(
                          height: 18,
                          child: Switch(
                            value: widget.value,
                            onChanged: widget.onChanged,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  void _toggleValue() {
    if (widget.onChanged != null) {
      widget.onChanged!(!widget.value);
    }
  }

  void _configureFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ??
        FocusNode(
          debugLabel:
              widget.debugLabel ?? 'rounded_switch_tile_${widget.key ?? 'row'}',
        );
  }
}
