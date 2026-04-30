import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';

const Map<String, Color> appCardHighlightPresetColors = <String, Color>{
  SettingsService.appCardHighlightColorLightBlue: Color(0xFF8ACBFF),
  SettingsService.appCardHighlightColorMint: Color(0xFF7BE0A5),
  SettingsService.appCardHighlightColorAmber: Color(0xFFFFC970),
  SettingsService.appCardHighlightColorCoral: Color(0xFFFF9A8B),
  SettingsService.appCardHighlightColorViolet: Color(0xFFC6A6FF),
  SettingsService.appCardHighlightColorWhite: Color(0xFFF5F7FF),
};

Color resolveAppCardHighlightPresetColor(String preset) {
  return appCardHighlightPresetColors[preset] ??
      appCardHighlightPresetColors[
          SettingsService.appCardHighlightColorDefault]!;
}
