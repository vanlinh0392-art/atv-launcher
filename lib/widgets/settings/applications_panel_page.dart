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
import 'package:flauncher/widgets/add_to_category_dialog.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../models/app.dart';
import '../../models/category.dart';

class ApplicationsPanelPage extends StatefulWidget {
  static const String routeName = "applications_panel";

  @override
  State<ApplicationsPanelPage> createState() => _ApplicationsPanelPageState();
}

class _ApplicationsPanelPageState extends State<ApplicationsPanelPage> {
  String _title = "";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    if (_title.isEmpty) {
      _title = localizations.tvApplications;
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Text(_title, style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          Material(
            type: MaterialType.transparency,
            child: TabBar(
              onTap: (index) {
                switch (index) {
                  case 0:
                    setState(() => _title = localizations.tvApplications);
                    break;
                  case 1:
                    setState(() => _title = localizations.nonTvApplications);
                    break;
                  case 2:
                    setState(() => _title = localizations.hiddenApplications);
                    break;
                  default:
                    throw ArgumentError.value(index, "index");
                }
              },
              tabs: const [
                Focus(autofocus: true, child: Tab(icon: Icon(Icons.tv))),
                Tab(icon: Icon(Icons.android)),
                Tab(icon: Icon(Icons.visibility_off_outlined)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
              child: TabBarView(
                  children: [_TVTab(), _SideloadedTab(), _HiddenTab()])),
        ],
      ),
    );
  }
}

class _TVTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Selector<AppsService, List<App>>(
        selector: (_, appsService) => appsService.applications
            .where((app) => !app.sideloaded && !app.hidden)
            .toList(),
        builder: (context, applications, _) => ListView(
          children: applications
              .map((application) => _AppListItem(application))
              .toList(),
        ),
      );
}

class _SideloadedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Selector<AppsService, List<App>>(
        selector: (_, appsService) => appsService.applications
            .where((app) => app.sideloaded && !app.hidden)
            .toList(),
        builder: (context, applications, _) => ListView(
          children: applications
              .map((application) => _AppListItem(application))
              .toList(),
        ),
      );
}

class _HiddenTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Selector<AppsService, List<App>>(
        selector: (_, appsService) =>
            appsService.applications.where((app) => app.hidden).toList(),
        builder: (context, applications, _) => ListView(
          children: applications
              .map((application) => _AppListItem(application))
              .toList(),
        ),
      );
}

class _AppListItem extends StatefulWidget {
  final App application;

  const _AppListItem(this.application);

  @override
  State<StatefulWidget> createState() => _AppListItemState();
}

class _AppListItemState extends State<_AppListItem> {
  late Future<ImageProvider> _iconLoadFuture;
  bool _focused = false;
  ImageProvider? _resolvedIcon;

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

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => ApplicationInfoPanel(
        category: null,
        application: widget.application,
        applicationIcon: _resolvedIcon,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _iconLoadFuture =
        _loadAppIcon(Provider.of<AppsService>(context, listen: false));
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _onFocusChange,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (isSettingsActivateKey(event.logicalKey)) {
          _showAppInfo();
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
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: FutureBuilder(
              future: _iconLoadFuture,
              builder: (context, snapshot) {
                Widget appIcon;

                if (snapshot.hasData) {
                  _resolvedIcon = snapshot.data;
                  appIcon = Image(image: snapshot.data!, height: 48);
                } else if (snapshot.hasError) {
                  appIcon = const Icon(Icons.warning);
                } else {
                  appIcon = const SizedBox(
                      height: 48,
                      width: 48,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ));
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    widget.application.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: appIcon,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!widget.application.hidden)
                        IconButton(
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                          icon: const Icon(Icons.add_box_outlined),
                          onPressed: () => showDialog<Category>(
                            context: context,
                            builder: (_) => AddToCategoryDialog(widget.application),
                          ),
                        ),
                      IconButton(
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                        icon: const Icon(Icons.info_outline),
                        onPressed: _showAppInfo,
                      ),
                    ],
                  ),
                );
              },
            )),
      ),
    );
  }

  Future<ImageProvider> _loadAppIcon(AppsService service) async {
    Uint8List bytes = await service.getAppIcon(widget.application.packageName);
    return MemoryImage(bytes);
  }
}
