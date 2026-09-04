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
  final BorderRadiusGeometry? borderRadius;

  const RightPanelDialog({
    super.key,
    required this.child,
    this.width = TvDrawerTokens.drawerWidth,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final chromeSpec = SettingsChromeSpec.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = (viewport.width * 0.38).clamp(380.0, 740.0);
    final effectiveBorderRadius = borderRadius ??
        BorderRadius.circular(
          dialogWidth <= 600 ? TvDrawerTokens.drawerRadius : 28.0,
        );

    return RepaintBoundary(
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(vertical: 18),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: SizedBox(
              width: dialogWidth,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: effectiveBorderRadius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: chromeSpec.dialogGradientColors,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(
                              chromeSpec.dialogBorderOpacity,
                            ),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                chromeSpec.dialogShadowOpacity,
                              ),
                              blurRadius: 14,
                              offset: const Offset(-4, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: Actions(
                      actions: {BackIntent: BackAction(context)},
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
