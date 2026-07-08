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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GradientPanelPage extends StatelessWidget {
  static const String routeName = "gradient_panel";

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text("Gradient", style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 4 / 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: FLauncherGradients.all
                  .map((gradient) => _GradientCardItem(
                      gradient: gradient,
                      autofocus: gradient == FLauncherGradients.greatWhale))
                  .toList(),
            ),
          ),
        ],
      );
}

class _GradientCardItem extends StatefulWidget {
  final FLauncherGradient gradient;
  final bool autofocus;

  const _GradientCardItem({
    required this.gradient,
    this.autofocus = false,
  });

  @override
  State<_GradientCardItem> createState() => _GradientCardItemState();
}

class _GradientCardItemState extends State<_GradientCardItem> {
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _onFocusChange,
      child: SettingsFocusFrame(
        padding: EdgeInsets.zero,
        focused: _focused,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: InkWell(
                  autofocus: widget.autofocus,
                  onTap: () => context
                      .read<WallpaperService>()
                      .setGradient(widget.gradient),
                  child: Container(
                      decoration: BoxDecoration(
                          gradient: widget.gradient.gradient)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                widget.gradient.name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _focused ? Colors.white : null,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

