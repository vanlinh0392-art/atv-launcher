import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ensure_visible.dart';
import 'settings/settings_chrome.dart';

class RoundedSwitchListTile extends StatelessWidget {
  final bool value;
  final bool autofocus;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget secondary;

  const RoundedSwitchListTile(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.title,
      required this.secondary,
      this.autofocus = false});

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.12,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _toggleValue,
            const SingleActivator(LogicalKeyboardKey.arrowRight): _toggleValue,
          },
          child: SettingsFocusFrame(
            padding: EdgeInsets.zero,
            child: TextButton(
              autofocus: autofocus,
              onPressed: onChanged == null ? null : _toggleValue,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
              ),
              child: Row(
                children: [
                  secondary,
                  const SizedBox(width: 12),
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  ExcludeFocus(
                    child: SizedBox(
                      height: 18,
                      child: Switch(
                        value: value,
                        onChanged: onChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  void _toggleValue() {
    if (onChanged != null) {
      onChanged!(!value);
    }
  }
}
