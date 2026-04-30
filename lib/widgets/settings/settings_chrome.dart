import 'dart:math' as math;

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

double _lerpOpacity(double solid, double transparent, double amount) =>
    solid + ((transparent - solid) * amount);

Color _accentWithOpacity(Color color, double opacity) => color.withOpacity(
      opacity.clamp(0.0, 1.0),
    );

enum SettingsButtonVariant {
  neutral,
  primary,
  success,
  danger,
}

enum SettingsFocusFrameVariant {
  detailPane,
  rowOnly,
  optionButton,
}

class SettingsFocusFrameVisuals {
  final Color fillColor;
  final Color borderColor;
  final Color glowColor;
  final Color shadowColor;
  final double borderWidth;
  final double glowBlurRadius;
  final double glowSpreadRadius;
  final Offset glowOffset;
  final double shadowBlurRadius;
  final Offset shadowOffset;

  const SettingsFocusFrameVisuals({
    required this.fillColor,
    required this.borderColor,
    required this.glowColor,
    required this.shadowColor,
    required this.borderWidth,
    required this.glowBlurRadius,
    required this.glowSpreadRadius,
    required this.glowOffset,
    required this.shadowBlurRadius,
    required this.shadowOffset,
  });
}

class SettingsChromeSpec {
  final double transparencyFraction;
  final double effectiveTransparencyFraction;

  const SettingsChromeSpec._(
    this.transparencyFraction,
    this.effectiveTransparencyFraction,
  );

  factory SettingsChromeSpec.fromTransparencyPercent(int transparencyPercent) {
    final rawFraction = (transparencyPercent / 100).clamp(0.0, 1.0);
    // Make low TV-facing steps like 5/10/15% visually meaningful instead of
    // feeling almost identical to 0%.
    final effectiveFraction = Curves.easeOutCubic.transform(rawFraction);
    return SettingsChromeSpec._(rawFraction, effectiveFraction);
  }

  factory SettingsChromeSpec.of(BuildContext context) {
    final settingsService = Provider.of<SettingsService?>(
      context,
      listen: true,
    );
    final transparencyPercent =
        settingsService?.settingsUiTransparencyPercent ??
            SettingsService.settingsUiTransparencyDefault;
    return SettingsChromeSpec.fromTransparencyPercent(transparencyPercent);
  }

  double get panelSurfaceOpacity =>
      _lerpOpacity(0.78, 0.05, effectiveTransparencyFraction);

  double get panelBorderOpacity =>
      _lerpOpacity(0.1, 0.014, effectiveTransparencyFraction);

  double get panelShadowOpacity =>
      _lerpOpacity(0.22, 0.035, effectiveTransparencyFraction);

  double get focusFillOpacity =>
      _lerpOpacity(0.2, 0.035, effectiveTransparencyFraction);

  double get focusBaseOpacity =>
      _lerpOpacity(0.09, 0.008, effectiveTransparencyFraction);

  double get metricTileOpacity =>
      _lerpOpacity(0.08, 0.004, effectiveTransparencyFraction);

  double get metricBorderOpacity =>
      _lerpOpacity(0.075, 0.012, effectiveTransparencyFraction);

  double get dialogGradientOpacity =>
      _lerpOpacity(0.92, 0.08, effectiveTransparencyFraction);

  double get dialogBorderOpacity =>
      _lerpOpacity(0.1, 0.018, effectiveTransparencyFraction);

  double get dialogShadowOpacity =>
      _lerpOpacity(0.44, 0.08, effectiveTransparencyFraction);

  double get detailFocusFillOpacity =>
      _lerpOpacity(0.085, 0.018, effectiveTransparencyFraction);

  double get detailFocusBorderOpacity =>
      _lerpOpacity(0.7, 0.2, effectiveTransparencyFraction);

  double get detailFocusGlowOpacity =>
      _lerpOpacity(0.14, 0.04, effectiveTransparencyFraction);

  double get detailFocusShadowOpacity =>
      _lerpOpacity(0.14, 0.035, effectiveTransparencyFraction);

  double get rowOnlyFocusFillOpacity =>
      _lerpOpacity(0.132, 0.03, effectiveTransparencyFraction);

  double get rowOnlyFocusBorderOpacity =>
      _lerpOpacity(0.78, 0.26, effectiveTransparencyFraction);

  double get rowOnlyFocusGlowOpacity =>
      _lerpOpacity(0.18, 0.052, effectiveTransparencyFraction);

  double get rowOnlyFocusShadowOpacity =>
      _lerpOpacity(0.16, 0.045, effectiveTransparencyFraction);

  double get actionButtonSurfaceOpacity =>
      _lerpOpacity(0.12, 0.038, effectiveTransparencyFraction);

  double get actionButtonFocusSurfaceOpacity =>
      _lerpOpacity(0.18, 0.078, effectiveTransparencyFraction);

  double get actionButtonFocusBorderOpacity =>
      _lerpOpacity(0.82, 0.5, effectiveTransparencyFraction);

  double get actionButtonFocusGlowOpacity =>
      _lerpOpacity(0.22, 0.1, effectiveTransparencyFraction);

  double get actionButtonPressedOpacity =>
      _lerpOpacity(0.28, 0.12, effectiveTransparencyFraction);

  SettingsFocusFrameVisuals resolveFocusFrameVisuals({
    required SettingsFocusFrameVariant variant,
    required bool focused,
    double emphasis = 1.0,
    Color accentColor = const Color(0xFF7EBCE8),
  }) {
    final emphasisBoost = (emphasis - 1.0).clamp(0.0, 1.0).toDouble();

    late final Color accent;
    late final double focusFillOpacity;
    late final double focusBorderOpacity;
    late final double focusGlowOpacity;
    late final double focusShadowOpacity;
    late final double focusedBorderWidth;
    late final double glowBlurRadius;
    late final double glowSpreadRadius;
    late final Offset glowOffset;
    late final double shadowBlurRadius;
    late final Offset shadowOffset;
    late final double idleFillOpacity;
    late final double idleBorderOpacity;
    late final double idleShadowOpacity;
    late final double idleShadowBlurRadius;
    late final Offset idleShadowOffset;

    switch (variant) {
      case SettingsFocusFrameVariant.detailPane:
        accent = const Color(0xFF88C8EE);
        focusFillOpacity =
            (detailFocusFillOpacity * (1 + (emphasisBoost * 1.8)))
                .clamp(0.0, 1.0)
                .toDouble();
        focusBorderOpacity =
            (detailFocusBorderOpacity * (1 + (emphasisBoost * 0.45)))
                .clamp(0.0, 1.0)
                .toDouble();
        focusGlowOpacity =
            (detailFocusGlowOpacity * (1 + (emphasisBoost * 0.85)))
                .clamp(0.0, 1.0)
                .toDouble();
        focusShadowOpacity =
            (detailFocusShadowOpacity * (1 + (emphasisBoost * 0.35)))
                .clamp(0.0, 1.0)
                .toDouble();
        focusedBorderWidth = 1.7 + (emphasisBoost * 0.45);
        glowBlurRadius = 10 + (emphasisBoost * 2);
        glowSpreadRadius = 0.4 + (emphasisBoost * 0.4);
        glowOffset = const Offset(0, 4);
        shadowBlurRadius = 8 + emphasisBoost;
        shadowOffset = const Offset(0, 5);
        idleFillOpacity = focusBaseOpacity;
        idleBorderOpacity = panelBorderOpacity;
        idleShadowOpacity = panelShadowOpacity - 0.02;
        idleShadowBlurRadius = 7;
        idleShadowOffset = const Offset(0, 4);
        break;
      case SettingsFocusFrameVariant.rowOnly:
        accent = const Color(0xFF7ABFE8);
        focusFillOpacity =
            (rowOnlyFocusFillOpacity * (1 + (emphasisBoost * 1.1)))
                .clamp(0.0, 1.0)
                .toDouble();
        focusBorderOpacity =
            (rowOnlyFocusBorderOpacity * (1 + (emphasisBoost * 0.28)))
                .clamp(0.0, 1.0)
                .toDouble();
        focusGlowOpacity =
            (rowOnlyFocusGlowOpacity * (1 + (emphasisBoost * 0.5)))
                .clamp(0.0, 1.0)
                .toDouble();
        focusShadowOpacity =
            (rowOnlyFocusShadowOpacity * (1 + (emphasisBoost * 0.25)))
                .clamp(0.0, 1.0)
                .toDouble();
        focusedBorderWidth = 2.0 + (emphasisBoost * 0.3);
        glowBlurRadius = 11 + emphasisBoost;
        glowSpreadRadius = 0.55 + (emphasisBoost * 0.25);
        glowOffset = const Offset(0, 4);
        shadowBlurRadius = 8.5 + (emphasisBoost * 0.6);
        shadowOffset = const Offset(0, 5);
        idleFillOpacity = focusBaseOpacity + 0.006;
        idleBorderOpacity = panelBorderOpacity + 0.018;
        idleShadowOpacity = panelShadowOpacity - 0.015;
        idleShadowBlurRadius = 7.5;
        idleShadowOffset = const Offset(0, 4);
        break;
      case SettingsFocusFrameVariant.optionButton:
        accent = accentColor;
        focusFillOpacity = actionButtonFocusSurfaceOpacity;
        focusBorderOpacity = actionButtonFocusBorderOpacity;
        focusGlowOpacity = actionButtonFocusGlowOpacity;
        focusShadowOpacity =
            math.min(actionButtonFocusGlowOpacity + 0.025, 0.34);
        focusedBorderWidth = 2.35 + (emphasisBoost * 0.15);
        glowBlurRadius = 14 + emphasisBoost;
        glowSpreadRadius = 0.8 + (emphasisBoost * 0.15);
        glowOffset = const Offset(0, 6);
        shadowBlurRadius = 11 + emphasisBoost;
        shadowOffset = const Offset(0, 6);
        idleFillOpacity = focusBaseOpacity + 0.018;
        idleBorderOpacity = panelBorderOpacity + 0.03;
        idleShadowOpacity = panelShadowOpacity;
        idleShadowBlurRadius = 8;
        idleShadowOffset = const Offset(0, 5);
        break;
    }

    if (!focused) {
      return SettingsFocusFrameVisuals(
        fillColor: Colors.white.withOpacity(idleFillOpacity),
        borderColor: Colors.white.withOpacity(idleBorderOpacity),
        glowColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(idleShadowOpacity),
        borderWidth: 1,
        glowBlurRadius: 0,
        glowSpreadRadius: 0,
        glowOffset: idleShadowOffset,
        shadowBlurRadius: idleShadowBlurRadius,
        shadowOffset: idleShadowOffset,
      );
    }

    return SettingsFocusFrameVisuals(
      fillColor: _accentWithOpacity(accent, focusFillOpacity),
      borderColor: _accentWithOpacity(accent, focusBorderOpacity),
      glowColor: _accentWithOpacity(accent, focusGlowOpacity),
      shadowColor: Colors.black.withOpacity(focusShadowOpacity),
      borderWidth: focusedBorderWidth,
      glowBlurRadius: glowBlurRadius,
      glowSpreadRadius: glowSpreadRadius,
      glowOffset: glowOffset,
      shadowBlurRadius: shadowBlurRadius,
      shadowOffset: shadowOffset,
    );
  }
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
        color:
            const Color(0xFF10233A).withOpacity(chromeSpec.panelSurfaceOpacity),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF86C5EE)
              : Colors.white.withOpacity(chromeSpec.panelBorderOpacity),
          width: highlighted ? 2.2 : 1.0,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF4A95D0)
                      .withOpacity(chromeSpec.panelShadowOpacity + 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.black
                      .withOpacity(chromeSpec.panelShadowOpacity + 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(chromeSpec.panelShadowOpacity),
                  blurRadius: 8,
                  offset: const Offset(0, 5),
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
  final double focusEmphasis;
  final SettingsFocusFrameVariant variant;
  final bool? focused;

  const SettingsFocusFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.baseColor = const Color(0x07FFFFFF),
    this.focusEmphasis = 1.0,
    this.variant = SettingsFocusFrameVariant.detailPane,
    this.focused,
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
    final resolvedFocused = widget.focused ?? _focused;
    final visuals = chromeSpec.resolveFocusFrameVisuals(
      variant: widget.variant,
      focused: resolvedFocused,
      emphasis: widget.focusEmphasis,
    );
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
          color: resolvedFocused
              ? visuals.fillColor
              : Color.alphaBlend(widget.baseColor, visuals.fillColor),
          borderRadius: borderRadius,
          border: Border.all(
            color: visuals.borderColor,
            width: visuals.borderWidth,
          ),
          boxShadow: resolvedFocused
              ? [
                  BoxShadow(
                    color: visuals.glowColor,
                    blurRadius: visuals.glowBlurRadius,
                    spreadRadius: visuals.glowSpreadRadius,
                    offset: visuals.glowOffset,
                  ),
                  BoxShadow(
                    color: visuals.shadowColor,
                    blurRadius: visuals.shadowBlurRadius,
                    offset: visuals.shadowOffset,
                  ),
                ]
              : [
                  BoxShadow(
                    color: visuals.shadowColor,
                    blurRadius: visuals.shadowBlurRadius,
                    offset: visuals.shadowOffset,
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

class SettingsMetricTile extends StatefulWidget {
  final FocusNode? focusNode;
  final bool autofocus;
  final String label;
  final String value;
  final IconData icon;
  final double? width;
  final Color? accentColor;

  const SettingsMetricTile({
    super.key,
    this.focusNode,
    this.autofocus = false,
    required this.label,
    required this.value,
    required this.icon,
    this.width,
    this.accentColor,
  });

  @override
  State<SettingsMetricTile> createState() => _SettingsMetricTileState();
}

class _SettingsMetricTileState extends State<SettingsMetricTile> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _configureFocusNode();
  }

  @override
  void didUpdateWidget(covariant SettingsMetricTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode &&
        oldWidget.label == widget.label) {
      return;
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    _configureFocusNode();
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chromeSpec = SettingsChromeSpec.of(context);
    final accentColor = widget.accentColor;
    final titleColor = _focused
        ? Colors.white
        : (accentColor?.withOpacity(0.96) ?? Colors.white.withOpacity(0.96));
    final subtitleColor =
        _focused ? Colors.white.withOpacity(0.84) : Colors.white70;
    final iconColor = _focused ? Colors.white : (accentColor ?? Colors.white70);
    final baseColor = accentColor == null
        ? Colors.white.withOpacity(chromeSpec.metricTileOpacity)
        : accentColor.withOpacity(chromeSpec.metricTileOpacity * 0.72);

    return EnsureVisible(
      alignment: EnsureVisible.settingsAlignment,
      settleFrameCount: 1,
      preferImmediate: true,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: true,
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() => _focused = value);
          }
        },
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SizedBox(
          width: widget.width,
          child: SettingsFocusFrame(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            borderRadius: BorderRadius.circular(20),
            baseColor: baseColor,
            focusEmphasis: 1.08,
            variant: SettingsFocusFrameVariant.rowOnly,
            focused: _focused,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 22, color: iconColor),
                const SizedBox(height: 10),
                Text(
                  widget.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight:
                            _focused ? FontWeight.w700 : FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: subtitleColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _configureFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    final debugToken = widget.label.trim().replaceAll(RegExp(r'\s+'), '_');
    _focusNode = widget.focusNode ??
        FocusNode(debugLabel: 'settings_metric_$debugToken');
  }
}

class SettingsSummarySection extends StatefulWidget {
  final String debugLabel;
  final FocusNode? focusNode;
  final Widget child;
  final double focusEmphasis;

  const SettingsSummarySection({
    super.key,
    required this.debugLabel,
    this.focusNode,
    required this.child,
    this.focusEmphasis = 1.12,
  });

  @override
  State<SettingsSummarySection> createState() => _SettingsSummarySectionState();
}

class _SettingsSummarySectionState extends State<SettingsSummarySection> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _configureFocusNode();
  }

  @override
  void didUpdateWidget(covariant SettingsSummarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode &&
        oldWidget.debugLabel == widget.debugLabel) {
      return;
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    _configureFocusNode();
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EnsureVisible(
      alignment: EnsureVisible.settingsAlignment,
      settleFrameCount: 1,
      preferImmediate: true,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: true,
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() => _focused = value);
          }
        },
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SettingsFocusFrame(
          padding: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(24),
          baseColor: Colors.transparent,
          focusEmphasis: widget.focusEmphasis,
          variant: SettingsFocusFrameVariant.rowOnly,
          focused: _focused,
          child: widget.child,
        ),
      ),
    );
  }

  void _configureFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: widget.debugLabel);
  }
}

class SettingsButtonStyles {
  static const Duration _duration = Duration(milliseconds: 110);
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(18));
  static const BorderRadius _compactRadius =
      BorderRadius.all(Radius.circular(16));

  static Color accentForVariant(SettingsButtonVariant variant) {
    switch (variant) {
      case SettingsButtonVariant.neutral:
        return const Color(0xFF8DB9D6);
      case SettingsButtonVariant.primary:
        return const Color(0xFF72BEF2);
      case SettingsButtonVariant.success:
        return const Color(0xFF62D89A);
      case SettingsButtonVariant.danger:
        return const Color(0xFFFF8F8F);
    }
  }

  static ButtonStyle filled(
    BuildContext context, {
    SettingsButtonVariant variant = SettingsButtonVariant.primary,
  }) {
    final spec = SettingsChromeSpec.of(context);
    final accent = accentForVariant(variant);
    return ButtonStyle(
      animationDuration: _duration,
      minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _radius),
      ),
      side: _actionSide(spec, accent),
      overlayColor: _overlay(spec, accent),
      shadowColor: _shadow(spec, accent),
      elevation: _elevation(focused: 6, idle: 1.5, disabled: 0),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  static ButtonStyle elevated(
    BuildContext context, {
    SettingsButtonVariant variant = SettingsButtonVariant.primary,
  }) {
    final spec = SettingsChromeSpec.of(context);
    final accent = accentForVariant(variant);
    return ButtonStyle(
      animationDuration: _duration,
      minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _radius),
      ),
      side: _actionSide(spec, accent),
      overlayColor: _overlay(spec, accent),
      shadowColor: _shadow(spec, accent),
      elevation: _elevation(focused: 7, idle: 2, disabled: 0),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  static ButtonStyle text(BuildContext context) {
    final spec = SettingsChromeSpec.of(context);
    const accent = Color(0xFF7EBCE8);
    return ButtonStyle(
      animationDuration: _duration,
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _radius),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white.withOpacity(0.02);
        }
        if (states.contains(WidgetState.focused)) {
          return _accentWithOpacity(
            accent,
            spec.actionButtonSurfaceOpacity,
          );
        }
        if (states.contains(WidgetState.pressed)) {
          return _accentWithOpacity(
            accent,
            spec.actionButtonFocusSurfaceOpacity,
          );
        }
        return Colors.white.withOpacity(spec.focusBaseOpacity + 0.012);
      }),
      overlayColor: _overlay(spec, accent),
      shadowColor: _shadow(spec, accent),
      elevation: _elevation(focused: 3.5, idle: 0, disabled: 0),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  static ButtonStyle icon(BuildContext context) {
    final spec = SettingsChromeSpec.of(context);
    const accent = Color(0xFF7EBCE8);
    return ButtonStyle(
      animationDuration: _duration,
      minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _compactRadius),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white.withOpacity(0.015);
        }
        if (states.contains(WidgetState.focused)) {
          return _accentWithOpacity(
            accent,
            spec.actionButtonSurfaceOpacity,
          );
        }
        return Colors.white.withOpacity(spec.focusBaseOpacity + 0.008);
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(
            color: _accentWithOpacity(
              accent,
              spec.actionButtonFocusBorderOpacity,
            ),
            width: 2,
          );
        }
        return BorderSide(
          color: Colors.white.withOpacity(spec.panelBorderOpacity + 0.02),
          width: 1,
        );
      }),
      overlayColor: _overlay(spec, accent),
      shadowColor: _shadow(spec, accent),
      elevation: _elevation(focused: 5, idle: 0, disabled: 0),
    );
  }

  static ButtonStyle mergeElevatedVariant(
    BuildContext context,
    ButtonStyle baseStyle, {
    required SettingsButtonVariant variant,
  }) {
    final spec = SettingsChromeSpec.of(context);
    final accent = accentForVariant(variant);
    return baseStyle.copyWith(
      animationDuration: _duration,
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _radius),
      ),
      side: _actionSide(spec, accent),
      overlayColor: _overlay(spec, accent),
      shadowColor: _shadow(spec, accent),
      elevation: _elevation(focused: 7, idle: 2, disabled: 0),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  static SettingsControlVisuals resolveControlVisuals(
    SettingsChromeSpec spec, {
    required SettingsButtonVariant variant,
    required bool focused,
    required bool enabled,
    required bool selected,
  }) {
    final accent = accentForVariant(variant);
    final optionFocusVisuals = spec.resolveFocusFrameVisuals(
      variant: SettingsFocusFrameVariant.optionButton,
      focused: true,
      accentColor: accent,
    );
    final optionIdleVisuals = spec.resolveFocusFrameVisuals(
      variant: SettingsFocusFrameVariant.optionButton,
      focused: false,
      accentColor: accent,
    );
    final fillColor = !enabled
        ? Colors.white.withOpacity(0.02)
        : focused
            ? optionFocusVisuals.fillColor
            : selected
                ? _accentWithOpacity(accent, spec.actionButtonSurfaceOpacity)
                : optionIdleVisuals.fillColor;
    final borderColor = !enabled
        ? Colors.white.withOpacity(0.04)
        : focused
            ? optionFocusVisuals.borderColor
            : selected
                ? _accentWithOpacity(accent, 0.7)
                : optionIdleVisuals.borderColor;
    final shadowColor = focused
        ? optionFocusVisuals.glowColor
        : Colors.black.withOpacity(spec.panelShadowOpacity);
    return SettingsControlVisuals(
      fillColor: fillColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      borderWidth:
          focused ? optionFocusVisuals.borderWidth : (selected ? 1.5 : 1),
      contentOpacity: enabled ? 1 : 0.42,
      scale: focused ? 1.024 : 1,
    );
  }

  static WidgetStateProperty<BorderSide?> _actionSide(
    SettingsChromeSpec spec,
    Color accent,
  ) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(
          color: Colors.white.withOpacity(spec.panelBorderOpacity),
          width: 1,
        );
      }
      if (states.contains(WidgetState.focused)) {
        return BorderSide(
          color: _accentWithOpacity(
            accent,
            spec.actionButtonFocusBorderOpacity,
          ),
          width: 2.3,
        );
      }
      if (states.contains(WidgetState.pressed)) {
        return BorderSide(
          color: _accentWithOpacity(accent, 0.82),
          width: 2.1,
        );
      }
      return BorderSide(
        color: Colors.white.withOpacity(spec.panelBorderOpacity + 0.025),
        width: 1,
      );
    });
  }

  static WidgetStateProperty<Color?> _overlay(
    SettingsChromeSpec spec,
    Color accent,
  ) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return _accentWithOpacity(accent, spec.actionButtonPressedOpacity);
      }
      if (states.contains(WidgetState.focused)) {
        return _accentWithOpacity(
          accent,
          spec.actionButtonFocusSurfaceOpacity,
        );
      }
      if (states.contains(WidgetState.hovered)) {
        return _accentWithOpacity(accent, spec.actionButtonSurfaceOpacity);
      }
      return null;
    });
  }

  static WidgetStateProperty<Color?> _shadow(
    SettingsChromeSpec spec,
    Color accent,
  ) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      if (states.contains(WidgetState.focused)) {
        return _accentWithOpacity(accent, spec.actionButtonFocusGlowOpacity);
      }
      return Colors.black.withOpacity(spec.panelShadowOpacity);
    });
  }

  static WidgetStateProperty<double?> _elevation({
    required double focused,
    required double idle,
    required double disabled,
  }) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabled;
      }
      if (states.contains(WidgetState.focused)) {
        return focused;
      }
      if (states.contains(WidgetState.pressed)) {
        return math.max(idle, focused - 1.5);
      }
      return idle;
    });
  }
}

class SettingsControlVisuals {
  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;
  final double borderWidth;
  final double contentOpacity;
  final double scale;

  const SettingsControlVisuals({
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
    required this.borderWidth,
    required this.contentOpacity,
    required this.scale,
  });
}
