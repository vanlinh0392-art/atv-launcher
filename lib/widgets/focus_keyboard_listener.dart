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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const longPressableKeys = [
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.gameButtonA
];

class FocusKeyboardListener extends StatefulWidget {
  final WidgetBuilder builder;
  final KeyEventResult Function(LogicalKeyboardKey)? onPressed;
  final KeyEventResult Function(LogicalKeyboardKey)? onLongPress;

  FocusKeyboardListener({
    Key? key,
    required this.builder,
    this.onPressed,
    this.onLongPress,
  }) : super(key: key);

  @override
  _FocusKeyboardListenerState createState() => _FocusKeyboardListenerState();
}

class _FocusKeyboardListenerState extends State<FocusKeyboardListener> {
  Timer? _longPressTimer;
  LogicalKeyboardKey? _pendingLongPressKey;
  bool _longPressTriggered = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        onKeyEvent: (_, keyEvent) => _handleKey(keyEvent),
        child: Builder(builder: widget.builder),
      );

  KeyEventResult _handleKey(KeyEvent keyEvent) {
    switch (keyEvent.runtimeType) {
      case KeyDownEvent:
        return _keyDownEvent(keyEvent.logicalKey);
      case KeyRepeatEvent:
        return _keyRepeatEvent(keyEvent.logicalKey);
      case KeyUpEvent:
        return _keyUpEvent(keyEvent.logicalKey);
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _keyDownEvent(LogicalKeyboardKey key) {
    if (!longPressableKeys.contains(key)) {
      return widget.onPressed?.call(key) ?? KeyEventResult.ignored;
    }

    if (_pendingLongPressKey != key) {
      _longPressTimer?.cancel();
      _pendingLongPressKey = key;
      _longPressTriggered = false;
      _longPressTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted || _pendingLongPressKey != key || _longPressTriggered) {
          return;
        }
        _longPressTriggered = true;
        widget.onLongPress?.call(key);
      });
    }

    return KeyEventResult.handled;
  }

  KeyEventResult _keyUpEvent(LogicalKeyboardKey key) {
    if (_pendingLongPressKey == key) {
      _longPressTimer?.cancel();
      _pendingLongPressKey = null;
      if (_longPressTriggered) {
        _longPressTriggered = false;
        return KeyEventResult.handled;
      }
      return widget.onPressed?.call(key) ?? KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _keyRepeatEvent(LogicalKeyboardKey key) {
    if (longPressableKeys.contains(key)) {
      if (_pendingLongPressKey != key) {
        return _keyDownEvent(key);
      }
      return KeyEventResult.handled;
    }
    return widget.onPressed?.call(key) ?? KeyEventResult.ignored;
  }
}
