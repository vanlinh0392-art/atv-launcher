import 'package:flutter_gen/gen_l10n/app_localizations.dart';

String localizedProvisioningHealth(
  AppLocalizations localizations,
  String health,
) {
  switch (health) {
    case 'healthy':
      return localizations.healthHealthy;
    case 'recommended_missing':
      return localizations.healthNeedsReview;
    default:
      return localizations.healthActionNeeded;
  }
}

String localizedBridgeHealth(
  AppLocalizations localizations,
  String health,
) {
  switch (health) {
    case 'healthy':
      return localizations.healthHealthy;
    case 'degraded':
      return localizations.healthDegraded;
    case 'missing_wss':
      return localizations.healthMissingWss;
    case 'repairing':
      return localizations.healthRepairing;
    default:
      return _humanizeCode(health);
  }
}

String localizedOnOff(AppLocalizations localizations, Object? value) =>
    value == true
        ? localizations.settingStateOn
        : localizations.settingStateOff;

String localizedYesNo(AppLocalizations localizations, Object? value) =>
    value == true ? localizations.yesLabel : localizations.noLabel;

String localizedGrantedMissing(AppLocalizations localizations, Object? value) =>
    value == true ? localizations.grantedLabel : localizations.missingLabel;

String localizedAdbPolicy(AppLocalizations localizations, String policy) {
  switch (policy) {
    case 'adb_only':
      return localizations.adbPolicyAdbOnly;
    case 'adb_and_wifi':
      return localizations.adbPolicyAdbAndWifi;
    default:
      return localizations.adbPolicyOff;
  }
}

String localizedVoiceMode(AppLocalizations localizations, int mode) {
  switch (mode) {
    case 1:
      return localizations.voiceModeSinglePress;
    case 2:
      return localizations.voiceModeLongPress;
    case 3:
      return localizations.voiceModeDoublePressHold;
    default:
      return localizations.voiceModeDoublePress;
  }
}

String localizedWallpaperMode(AppLocalizations localizations, String mode) {
  switch (mode) {
    case 'image':
      return localizations.wallpaperModeImage;
    case 'video':
      return localizations.wallpaperModeVideo;
    default:
      return localizations.wallpaperModeGradient;
  }
}

String localizedVideoSourceType(
  AppLocalizations localizations,
  String sourceType,
) {
  switch (sourceType) {
    case 'multi_file_playlist':
      return localizations.videoSourceMultipleFiles;
    case 'folder_playlist':
      return localizations.videoSourceFolder;
    case 'single_file':
      return localizations.videoSourceSingleFile;
    default:
      return _humanizeCode(sourceType);
  }
}

String localizedPrivateDnsMode(
  AppLocalizations localizations,
  String mode,
) {
  switch (mode) {
    case 'off':
      return localizations.privateDnsModeOff;
    case 'hostname':
      return localizations.privateDnsModeHostname;
    case 'opportunistic':
      return localizations.privateDnsModeOpportunistic;
    default:
      return _humanizeCode(mode);
  }
}

String localizedVideoOrderMode(
  AppLocalizations localizations,
  String mode,
) {
  switch (mode) {
    case 'shuffle':
      return localizations.shuffleOrder;
    default:
      return localizations.sequentialOrder;
  }
}

String localizedVideoAdvanceMode(
  AppLocalizations localizations,
  String mode,
) {
  switch (mode) {
    case 'fixed_interval':
      return localizations.fixedInterval;
    default:
      return localizations.onCompletion;
  }
}

String localizedVideoFit(AppLocalizations localizations, String fit) {
  switch (fit) {
    case 'fit':
      return localizations.videoFitFit;
    case 'fill':
      return localizations.videoFitFill;
    default:
      return localizations.videoFitCenterCrop;
  }
}

String localizedVideoBlur(AppLocalizations localizations, String blur) {
  switch (blur) {
    case 'low':
      return localizations.videoBlurLow;
    case 'medium':
      return localizations.videoBlurMedium;
    case 'high':
      return localizations.videoBlurHigh;
    default:
      return localizations.videoBlurOff;
  }
}

String _humanizeCode(String value) {
  if (value.isEmpty) {
    return '-';
  }
  final text = value.replaceAll('_', ' ').trim();
  if (text.isEmpty) {
    return '-';
  }
  return text[0].toUpperCase() + text.substring(1);
}
