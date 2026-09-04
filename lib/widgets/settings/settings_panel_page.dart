import 'package:flauncher/widgets/settings/accessibility_manager_panel_page.dart';
import 'package:flauncher/widgets/settings/backup_restore_panel_page.dart';
import 'package:flauncher/widgets/settings/density_panel_page.dart';
import 'package:flauncher/widgets/settings/home_layout_panel_page.dart';
import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/settings/private_dns_panel_page.dart';
import 'package:flauncher/widgets/settings/profiles_security_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/system_core_panel_page.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flauncher/widgets/settings/update_panel_page.dart';
import 'package:flauncher/widgets/settings/voice_search_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsPanelPage extends StatefulWidget {
  static const String routeName = "settings_panel";
  final String? initialSelectedRoute;
  final ValueChanged<String>? onBenchmarkReady;

  const SettingsPanelPage({
    super.key,
    this.initialSelectedRoute,
    this.onBenchmarkReady,
  });

  @override
  State<SettingsPanelPage> createState() => _SettingsPanelPageState();
}

class _SettingsPanelPageState extends State<SettingsPanelPage> {
  final Map<String, FocusNode> _itemFocusNodes = <String, FocusNode>{};
  String? _lastFocusedRoute;

  String? get lastFocusedRoute => _lastFocusedRoute;

  @override
  void initState() {
    super.initState();
    if (widget.onBenchmarkReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onBenchmarkReady?.call('settings_menu_root');
        }
      });
    }
  }

  @override
  void dispose() {
    for (final node in _itemFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final destinations = _destinations(localizations);

    return SettingsContentView(
      title: localizations.settingsShellTitle,
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: ListView.separated(
          key: const PageStorageKey<String>('settings_menu_root'),
          cacheExtent: 3000,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: destinations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = destinations[index];
            final focusNode = _itemFocusNodes.putIfAbsent(
              item.route,
              () => FocusNode(debugLabel: 'settings_card_${item.route}'),
            );
            final isAutofocus = widget.initialSelectedRoute != null
                ? item.route == widget.initialSelectedRoute
                : index == 0;
            return SettingsActionCard(
              key: ValueKey<String>('settings_card_${item.route}'),
              focusNode: focusNode,
              autofocus: isAutofocus,
              icon: item.icon,
              title: item.title,
              titleMaxLines: 1,
              onPressed: () async {
                _lastFocusedRoute = item.route;
                await Navigator.of(context).pushNamed(item.route);
                if (mounted) {
                  _itemFocusNodes[item.route]?.requestFocus();
                }
              },
            );
          },
        ),
      ),
    );
  }

  List<_SettingsCategoryItem> _destinations(AppLocalizations localizations) => [
        _SettingsCategoryItem(
          route: HomeLayoutPanelPage.routeName,
          icon: Icons.home_outlined,
          title: localizations.settingsDestinationHomeTitle,
        ),
        _SettingsCategoryItem(
          route: WallpaperPanelPage.routeName,
          icon: Icons.wallpaper_outlined,
          title: localizations.settingsDestinationWallpaperTitle,
        ),
        _SettingsCategoryItem(
          route: VoiceSearchPanelPage.routeName,
          icon: Icons.auto_awesome,
          title: localizations.settingsDestinationVoiceTitle,
        ),
        _SettingsCategoryItem(
          route: ProfilesSecurityPanelPage.routeName,
          icon: Icons.admin_panel_settings_outlined,
          title: localizations.settingsDestinationProfilesTitle,
        ),
        _SettingsCategoryItem(
          route: AccessibilityManagerPanelPage.routeName,
          icon: Icons.settings_accessibility,
          title: localizations.settingsDestinationAccessibilityTitle,
        ),
        _SettingsCategoryItem(
          route: SystemCorePanelPage.routeName,
          icon: Icons.memory_outlined,
          title: localizations.settingsDestinationSystemCoreTitle,
        ),
        _SettingsCategoryItem(
          route: DensityPanelPage.routeName,
          icon: Icons.monitor_outlined,
          title: localizations.settingsDestinationDensityTitle,
        ),
        _SettingsCategoryItem(
          route: PrivateDnsPanelPage.routeName,
          icon: Icons.router_outlined,
          title: localizations.settingsDestinationPrivateDnsTitle,
        ),
        _SettingsCategoryItem(
          route: PermissionsPanelPage.routeName,
          icon: Icons.verified_user_outlined,
          title: localizations.settingsDestinationPermissionsTitle,
        ),
        _SettingsCategoryItem(
          route: BackupRestorePanelPage.routeName,
          icon: Icons.inventory_2_outlined,
          title: localizations.settingsDestinationBackupTitle,
        ),
        _SettingsCategoryItem(
          route: UpdatePanelPage.routeName,
          icon: Icons.system_update_outlined,
          title: localizations.settingsDestinationUpdatesTitle,
        ),
      ];
}

class _SettingsCategoryItem {
  final String route;
  final IconData icon;
  final String title;

  const _SettingsCategoryItem({
    required this.route,
    required this.icon,
    required this.title,
  });
}

