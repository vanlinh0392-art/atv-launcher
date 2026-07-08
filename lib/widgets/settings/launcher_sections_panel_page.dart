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

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/launcher_section_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../models/category.dart';

class LauncherSectionsPanelPage extends StatelessWidget {
  static const String routeName = "launcher_sections_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(localizations.launcherSections,
            style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Consumer<AppsService>(
          builder: (_, service, __) {
            List<LauncherSection> sections = service.launcherSections;

            return Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: sections.indexed.map((tuple) {
                    int index = tuple.$1;
                    bool last = index == sections.length - 1;

                    return _SectionItem(
                      section: sections[index],
                      index: index,
                      last: last,
                      autofocus: index == 0,
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4, width: 0),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text(localizations.addSection),
          onPressed: () {
            Navigator.pushNamed(context, LauncherSectionPanelPage.routeName);
          },
        ),
      ],
    );
  }
}

class _SectionItem extends StatefulWidget {
  final LauncherSection section;
  final int index;
  final bool last;
  final bool autofocus;

  const _SectionItem({
    required this.section,
    required this.index,
    required this.last,
    this.autofocus = false,
  });

  @override
  State<_SectionItem> createState() => _SectionItemState();
}

class _SectionItemState extends State<_SectionItem> {
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
    AppLocalizations localizations = AppLocalizations.of(context)!;
    String title = localizations.spacer;
    if (widget.section is Category) {
      title = (widget.section as Category).name;
      if (title == localizations.spacer) {
        title = localizations.disambiguateCategoryTitle(title);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Focus(
        onFocusChange: _onFocusChange,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (isSettingsActivateKey(event.logicalKey)) {
            Navigator.pushNamed(
                context, LauncherSectionPanelPage.routeName,
                arguments: widget.index);
            return KeyEventResult.handled;
          }
          final direction = event.logicalKey == LogicalKeyboardKey.arrowUp
              ? TraversalDirection.up
              : event.logicalKey == LogicalKeyboardKey.arrowDown
                  ? TraversalDirection.down
                  : null;
          if (direction != null) {
            if (!moveSettingsVerticalFocus(
              direction: direction,
              localNodes: <FocusNode>[node],
            )) {
              node.focusInDirection(direction);
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SettingsFocusFrame(
          padding: EdgeInsets.zero,
          variant: SettingsFocusFrameVariant.rowOnly,
          focused: _focused,
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              autofocus: widget.autofocus,
              title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: widget.index > 0
                        ? () => _move(context, widget.index, widget.index - 1)
                        : null,
                  ),
                  IconButton(
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: widget.last
                        ? null
                        : () => _move(context, widget.index, widget.index + 1),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.pushNamed(
                          context, LauncherSectionPanelPage.routeName,
                          arguments: widget.index);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _move(BuildContext context, int oldIndex, int newIndex) async {
    await context.read<AppsService>().moveSection(oldIndex, newIndex);
  }
}

