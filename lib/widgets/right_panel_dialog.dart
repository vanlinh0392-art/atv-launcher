/*
 * FLauncher
 * Copyright (C) 2021  Etienne Fesser
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

import 'package:flauncher/actions.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flutter/material.dart';

class RightPanelDialog extends StatelessWidget {
  final Widget child;
  final double width;

  const RightPanelDialog({
    super.key,
    required this.child,
    this.width = 960,
  });

  @override
  Widget build(BuildContext context) {
    final chromeSpec = SettingsChromeSpec.of(context);
    final viewport = MediaQuery.of(context).size;
    final dialogWidth = width.clamp(720, viewport.width - 48).toDouble();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal:
            (viewport.width - dialogWidth).clamp(24, viewport.width).toDouble(),
        vertical: 18,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFF0D2036)
                    .withOpacity(chromeSpec.dialogGradientOpacity),
                const Color(0xFF112845)
                    .withOpacity(chromeSpec.dialogGradientOpacity - 0.03),
                const Color(0xFF091523)
                    .withOpacity(chromeSpec.dialogGradientOpacity - 0.06),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(chromeSpec.dialogBorderOpacity),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(chromeSpec.dialogShadowOpacity),
                blurRadius: 36,
                offset: Offset(-10, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: SizedBox(
              width: dialogWidth,
              child: Actions(
                actions: {BackIntent: BackAction(context)},
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
