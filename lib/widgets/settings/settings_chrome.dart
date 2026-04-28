import 'dart:math' as math;

import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

double _lerpOpacity(double solid, double transparent, double amount) =>
    solid + ((transparent - solid) * amount);

class SettingsChromeSpec {
  final double transparencyFraction;

  const SettingsChromeSpec._(this.transparencyFraction);

  factory SettingsChromeSpec.of(BuildContext context) {
    final settingsService = context.watch<SettingsService?>();
    final transparencyPercent = settingsService?.settingsUiTransparencyPercent ??
        SettingsService.settingsUiTransparencyDefault;
    return SettingsChromeSpec._(
      (transparencyPercent / 100).clamp(0.0, 1.0),
    );
  }

  double get panelSurfaceOpacity =>
      _lerpOpacity(0.72, 0.16, transparencyFraction);

  double get panelBorderOpacity =>
      _lerpOpacity(0.08, 0.035, transparencyFraction);

  double get panelShadowOpacity =>
      _lerpOpacity(0.16, 0.06, transparencyFraction);

  double get focusFillOpacity =>
      _lerpOpacity(0.16, 0.05, transparencyFraction);

  double get focusBaseOpacity =>
      _lerpOpacity(0.07, 0.015, transparencyFraction);

  double get metricTileOpacity =>
      _lerpOpacity(0.04, 0.012, transparencyFraction);

  double get metricBorderOpacity =>
      _lerpOpacity(0.055, 0.02, transparencyFraction);

  double get dialogGradientOpacity =>
      _lerpOpacity(0.82, 0.28, transparencyFraction);

  double get dialogBorderOpacity =>
      _lerpOpacity(0.08, 0.03, transparencyFraction);

  double get dialogShadowOpacity =>
      _lerpOpacity(0.36, 0.14, transparencyFraction);
}

class SettingsContentView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const SettingsContentView({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(child: child),
      ],
    );
  }
}

class SettingsSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  const SettingsSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final chromeSpec = SettingsChromeSpec.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10233A).withOpacity(chromeSpec.panelSurfaceOpacity),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF9ED4FF)
              : Colors.white.withOpacity(chromeSpec.panelBorderOpacity),
          width: highlighted ? 2.2 : 1.0,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF2A6BD8)
                      .withOpacity(chromeSpec.panelShadowOpacity + 0.06),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black
                      .withOpacity(chromeSpec.panelShadowOpacity + 0.02),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(chromeSpec.panelShadowOpacity),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class SettingsAdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double minChildWidth;
  final int? maxColumns;

  const SettingsAdaptiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.minChildWidth = 260,
    this.maxColumns,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final resolvedMaxColumns = math.max(
          1,
          math.min(
            maxColumns ?? (children.length >= 5 ? 3 : 2),
            children.length,
          ),
        );
        final calculatedColumns =
            ((availableWidth + spacing) / (minChildWidth + spacing))
                .floor()
                .clamp(1, resolvedMaxColumns);
        final itemWidth =
            (availableWidth - (spacing * math.max(0, calculatedColumns - 1))) /
                calculatedColumns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  child: child,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class SettingsFocusFrame extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color baseColor;

  const SettingsFocusFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.baseColor = const Color(0x07FFFFFF),
  });

  @override
  State<SettingsFocusFrame> createState() => _SettingsFocusFrameState();
}

class _SettingsFocusFrameState extends State<SettingsFocusFrame> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius;
    final chromeSpec = SettingsChromeSpec.of(context);
    return Focus(
      canRequestFocus: false,
      onFocusChange: (value) {
        if (_focused != value) {
          setState(() => _focused = value);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _focused
              ? const Color(0xFF2F7BF5).withOpacity(chromeSpec.focusFillOpacity)
              : Colors.white.withOpacity(chromeSpec.focusBaseOpacity),
          borderRadius: borderRadius,
          border: Border.all(
            color: _focused
                ? const Color(0xFF9ED4FF)
                : Colors.white.withOpacity(chromeSpec.panelBorderOpacity),
            width: _focused ? 2.4 : 1,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: const Color(0xFF2A6BD8)
                        .withOpacity(chromeSpec.panelShadowOpacity + 0.02),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(chromeSpec.panelShadowOpacity),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(chromeSpec.panelShadowOpacity - 0.01),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }
}

class SettingsStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const SettingsStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.36)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class SettingsMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double? width;

  const SettingsMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final chromeSpec = SettingsChromeSpec.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(chromeSpec.metricTileOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(chromeSpec.metricBorderOpacity),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
