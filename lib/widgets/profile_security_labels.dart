import 'package:flauncher/models/launcher_profile.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

String localizedProfileName(
  AppLocalizations localizations,
  LauncherProfile profile,
) {
  final raw = profile.displayName.trim();
  if (raw.isEmpty || _isDefaultName(profile.type, raw)) {
    return switch (profile.type) {
      LauncherProfileType.owner => localizations.ownerProfileName,
      LauncherProfileType.guest => localizations.guestProfileName,
      LauncherProfileType.kids => localizations.kidsProfileName,
    };
  }
  return raw;
}

String localizedProfileDescription(
  AppLocalizations localizations,
  LauncherProfileType type,
) =>
    switch (type) {
      LauncherProfileType.owner => localizations.ownerProfileDescription,
      LauncherProfileType.guest => localizations.guestProfileDescription,
      LauncherProfileType.kids => localizations.kidsProfileDescription,
    };

bool _isDefaultName(LauncherProfileType type, String value) {
  final normalized = value.trim().toLowerCase();
  return switch (type) {
    LauncherProfileType.owner => normalized == 'owner',
    LauncherProfileType.guest => normalized == 'guest',
    LauncherProfileType.kids => normalized == 'kids',
  };
}
