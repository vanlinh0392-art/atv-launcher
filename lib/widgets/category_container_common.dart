import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'ensure_visible.dart';

Widget categoryContainerEmptyState(
  BuildContext context, {
  bool autofocus = false,
  FocusNode? focusNode,
  ValueChanged<bool>? onFocusChange,
}) {
  AppLocalizations localizations = AppLocalizations.of(context)!;

  return SizedBox(
    height: 110,
    child: EnsureVisible(
      // This specific alignment value is not only
      // to center the focused card in the row while
      // scrolling, but to prevent the topmost category
      // title to be hidden by the content above it when
      // scrolling from the app bar. How it relates to this,
      // I don't know
      alignment: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: InkWell(
                autofocus: autofocus,
                focusNode: focusNode,
                onFocusChange: onFocusChange,
                onTap: () async {
                  final security = context.read<ProfileSecurityService>();
                  if (await security.ensureSecurityAccess(context)) {
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (_) => const SettingsPanel(
                        initialRoute: LauncherSectionsPanelPage.routeName,
                      ),
                    );
                    if (context.mounted &&
                        focusNode != null &&
                        focusNode.canRequestFocus) {
                      focusNode.requestFocus();
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        localizations.textEmptyCategory,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
