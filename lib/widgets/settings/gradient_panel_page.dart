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

import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class GradientPanelPage extends StatelessWidget {
  static const String routeName = "gradient_panel";

  @override
  Widget build(BuildContext context) {
    final currentGradient = context.watch<WallpaperService>().gradient;

    return Column(
      children: [
        Text("Gradient", style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.35,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            children: FLauncherGradients.all
                .map((gradient) => _GradientSwatchItem(
                      gradient: gradient,
                      isSelected: gradient.uuid == currentGradient.uuid,
                      autofocus: gradient == currentGradient ||
                          (currentGradient == FLauncherGradients.greatWhale &&
                              gradient == FLauncherGradients.greatWhale),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _GradientSwatchItem extends StatefulWidget {
  final FLauncherGradient gradient;
  final bool isSelected;
  final bool autofocus;

  const _GradientSwatchItem({
    required this.gradient,
    required this.isSelected,
    this.autofocus = false,
  });

  @override
  State<_GradientSwatchItem> createState() => _GradientSwatchItemState();
}

class _GradientSwatchItemState extends State<_GradientSwatchItem> {
  bool _focused = false;

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.3,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _selectGradient() {
    context.read<WallpaperService>().setGradient(widget.gradient);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      key: Key('gradient-${widget.gradient.uuid}'),
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (isSettingsActivateKey(event.logicalKey)) {
          _selectGradient();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SettingsFocusFrame(
        padding: EdgeInsets.zero,
        focused: _focused,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _selectGradient,
          child: Container(
            decoration: BoxDecoration(
              gradient: widget.gradient.gradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focused
                    ? const Color(0xFF00E5FF)
                    : (widget.isSelected
                        ? Colors.white.withOpacity(0.9)
                        : Colors.white.withOpacity(0.2)),
                width: _focused ? 2.0 : (widget.isSelected ? 2.0 : 1.0),
              ),
              boxShadow: _focused
                  ? const [
                      BoxShadow(
                        color: Color(0x9900E5FF),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : (widget.isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null),
            ),
            child: widget.isSelected
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.85),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}


