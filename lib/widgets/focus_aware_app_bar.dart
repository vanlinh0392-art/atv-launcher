import 'package:flauncher/widgets/settings/permissions_panel_page.dart';
import 'package:flauncher/widgets/pin_pad_dialog.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/settings_service.dart';
import '../providers/system_bridge_service.dart';
import 'date_time_widget.dart';
import 'network_widget.dart';

class FocusAwareAppBar extends StatefulWidget implements PreferredSizeWidget {
  final FocusNode? primaryFocusNode;

  const FocusAwareAppBar({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<StatefulWidget> createState() {
    return _FocusAwareAppBarState();
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class _FocusAwareAppBarState extends State<FocusAwareAppBar> {
  bool focused = false;

  Future<void> _openSettings(BuildContext context,
      {String? initialRoute}) async {
    final localizations = AppLocalizations.of(context)!;
    final allowed = await ensureSecurityAccess(
      context,
      title: localizations.unlockSettingsTitle,
      description: localizations.unlockSettingsDescription,
    );
    if (!allowed || !context.mounted) {
      return;
    }
    final wallpaperService = context.read<WallpaperService>();
    wallpaperService.cancelPendingHomeVideoStart();
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsPanel(initialRoute: initialRoute),
    );
    if (!context.mounted) {
      return;
    }
    wallpaperService.notifyHomeVisibleAndUsable();
  }

  Future<void> _startVoiceSearch(BuildContext context) async {
    final result = await context.read<SystemBridgeService>().testVoiceSearch();
    if (!context.mounted) {
      return;
    }
    if (result['success'] == true) {
      return;
    }
    final message = result['message']?.toString().trim();
    if (message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleHomeReorderMode(BuildContext context) {
    context.read<AppsService>().toggleHomeReorderMode();
  }

  Future<void> _openWifiSettings(BuildContext context) async {
    await context.read<SystemBridgeService>().openSpecificSettingsPage('wifi');
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1000;
    final showRam = context.select<SettingsService, bool>(
      (settings) => settings.showRamInStatusBar,
    );
    final homeReorderModeEnabled = context.select<AppsService, bool>(
      (service) => service.homeReorderModeEnabled,
    );
    return Selector<SettingsService, bool>(
        selector: (_, settings) => settings.autoHideAppBarEnabled,
        builder: (context, autoHide, widget) {
          if (autoHide) {
            return Focus(
                canRequestFocus: false,
                child: AnimatedContainer(
                    curve: Curves.decelerate,
                    duration: const Duration(milliseconds: 250),
                    height: focused ? kToolbarHeight : 0,
                    child: widget!),
                onFocusChange: (hasFocus) {
                  setState(() {
                    focused = hasFocus;
                  });
                });
          }

          return widget!;
        },
        child: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: showRam
              ? (isCompact
                  ? _statusBarRamChipLeadingWidthCompact
                  : _statusBarRamChipLeadingWidthRegular)
              : 18,
          titleSpacing: showRam ? 12 : 16,
          leading: showRam
              ? const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _MemoryStatusChip(),
                  ),
                )
              : const SizedBox.shrink(),
          actions: [
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: isCompact ? 16 : 32,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusBarIconButton(
                    focusNode: widget.primaryFocusNode,
                    icon: Icons.search_rounded,
                    tooltip: AppLocalizations.of(context)!.searchHint,
                    onPressed: () => _startVoiceSearch(context),
                  ),
                  const SizedBox(width: _statusBarActionSpacing),
                  _StatusBarIconButton(
                    icon: homeReorderModeEnabled
                        ? Icons.open_with_rounded
                        : Icons.drive_file_move_outline,
                    tooltip: AppLocalizations.of(context)!.reorder,
                    iconColor: homeReorderModeEnabled
                        ? const Color(0xFF7BE0A5)
                        : _statusBarGlyphColor,
                    badgeColor:
                        homeReorderModeEnabled ? const Color(0xFF7BE0A5) : null,
                    onPressed: () => _toggleHomeReorderMode(context),
                  ),
                  const SizedBox(width: _statusBarActionSpacing),
                  _StatusBarIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: AppLocalizations.of(context)!.settings,
                    onPressed: () => _openSettings(context),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: _statusBarActionSpacing),
                    _StatusBarActionSurface(
                      tooltip: AppLocalizations.of(context)!.openWifiSettings,
                      onPressed: () => _openWifiSettings(context),
                      child: IconTheme.merge(
                        data: const IconThemeData(
                          color: _statusBarGlyphColor,
                          size: _statusBarGlyphSize,
                        ),
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(color: _statusBarGlyphColor),
                          child: const NetworkWidget(),
                        ),
                      ),
                    ),
                    const SizedBox(width: _statusBarActionSpacing),
                    _GrantHealthChipButton(
                      onPressed: () => _openSettings(
                        context,
                        initialRoute: PermissionsPanelPage.routeName,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Selector<
                        SettingsService,
                        ({
                          bool showDateInStatusBar,
                          bool showTimeInStatusBar,
                          String dateFormat,
                          String timeFormat,
                          int clockScalePercent
                        })>(
                      selector: (context, service) => (
                        showDateInStatusBar: service.showDateInStatusBar,
                        showTimeInStatusBar: service.showTimeInStatusBar,
                        dateFormat: service.dateFormat,
                        timeFormat: service.timeFormat,
                        clockScalePercent: service.statusBarClockScalePercent
                      ),
                      builder: (context, dateTimeSettings, _) {
                        final scale =
                            dateTimeSettings.clockScalePercent.clamp(100, 180) /
                                100.0;
                        return Row(mainAxisSize: MainAxisSize.min, children: [
                          if (dateTimeSettings.showDateInStatusBar)
                            DateTimeWidget(
                              dateTimeSettings.dateFormat,
                              updateInterval: const Duration(minutes: 1),
                              textStyle: _scaledStatusBarTextStyle(
                                context,
                                scale: scale,
                              ),
                            ),
                          if (dateTimeSettings.showDateInStatusBar &&
                              dateTimeSettings.showTimeInStatusBar)
                            const SizedBox(width: 16),
                          if (dateTimeSettings.showTimeInStatusBar)
                            DateTimeWidget(
                              dateTimeSettings.timeFormat,
                              textStyle: _scaledStatusBarTextStyle(
                                context,
                                scale: scale,
                              ),
                            )
                        ]);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ));
  }
}

class _GrantHealthChipButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GrantHealthChipButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Selector<SystemBridgeService, Map<String, dynamic>>(
      selector: (_, service) => service.provisioningStatus,
      builder: (context, provisioning, _) {
        final int missingRequired =
            ((provisioning['missingRequiredCount'] as num?) ?? 0).toInt();
        final int missingRecommended =
            ((provisioning['missingRecommendedCount'] as num?) ?? 0).toInt();
        final List requirements =
            (provisioning['requirements'] as List?) ?? const [];
        final int fallbackMissing = requirements
            .where((item) => item is Map && item['granted'] != true)
            .length;
        final String health =
            provisioning['health']?.toString() ?? 'missing_required';
        final int missingCount = missingRequired > 0
            ? missingRequired
            : (missingRecommended > 0 ? missingRecommended : fallbackMissing);
        final Color color = switch (health) {
          'healthy' => const Color(0xFF7BE0A5),
          'recommended_missing' => const Color(0xFFFFC970),
          _ => const Color(0xFFFF8A80),
        };
        final IconData icon = switch (health) {
          'healthy' => Icons.gpp_good_outlined,
          'recommended_missing' => Icons.gpp_maybe_outlined,
          _ => Icons.gpp_bad_outlined,
        };
        final String label = switch (health) {
          'healthy' => localizations.grantChipHealthy,
          'recommended_missing' =>
            localizations.grantChipRecommended(missingCount),
          _ => localizations.grantChipMissing(missingCount),
        };
        return _StatusBarChipButton(
          icon: icon,
          label: label,
          color: color,
          badgeColor: color,
          onPressed: onPressed,
        );
      },
    );
  }
}

class _MemoryStatusChip extends StatelessWidget {
  const _MemoryStatusChip();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Selector<SystemBridgeService, Map<String, dynamic>>(
      selector: (_, service) => service.memoryStatus,
      builder: (context, map, _) {
        final num? availableBytes = map['availBytes'] as num?;
        final num? totalBytes = map['totalBytes'] as num?;
        final bool lowMemory = map['lowMemory'] == true;
        final bool hasReadableMemory =
            availableBytes != null && totalBytes != null && totalBytes > 0;
        final String rawValue = hasReadableMemory
            ? '${_formatBytesCompact(availableBytes)}/${_formatBytesCompact(totalBytes)}'
            : '--/--';
        final String semanticsLabel = !hasReadableMemory
            ? localizations.ramChipUnavailable
            : localizations.ramChipLabel(
                _formatBytesVerbose(availableBytes),
                _formatBytesVerbose(totalBytes),
              );
        return Semantics(
          label: semanticsLabel,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rawValue,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: lowMemory
                      ? const Color(0xFFFF8A80)
                      : const Color(0xFFF5F8FF),
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(0, 1),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatBytesCompact(num bytes) {
    final gigabytes = bytes / (1024 * 1024 * 1024);
    if (gigabytes >= 1) {
      return '${_formatDecimal(gigabytes, suffix: 'G')}';
    }
    final megabytes = bytes / (1024 * 1024);
    return '${_formatDecimal(megabytes, suffix: 'M')}';
  }

  String _formatBytesVerbose(num bytes) {
    final gigabytes = bytes / (1024 * 1024 * 1024);
    if (gigabytes >= 1) {
      return '${_formatDecimal(gigabytes, suffix: ' GB')}';
    }
    final megabytes = bytes / (1024 * 1024);
    return '${_formatDecimal(megabytes, suffix: ' MB')}';
  }

  String _formatDecimal(
    num value, {
    required String suffix,
  }) {
    final decimals = value >= 10 ? 0 : 1;
    final formatted = value.toStringAsFixed(decimals);
    final normalized = formatted.endsWith('.0')
        ? formatted.substring(0, formatted.length - 2)
        : formatted;
    return '$normalized$suffix';
  }
}

class _StatusBarChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final Color? badgeColor;

  const _StatusBarChipButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: onPressed != null,
        label: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(
            width: _statusBarActionExtent,
            height: _statusBarActionExtent,
          ),
          child: _StatusBarActionSurface(
            tooltip: label,
            onPressed: onPressed,
            badgeColor: badgeColor,
            child: Icon(
              icon,
              size: _statusBarGlyphSize,
              color: color,
            ),
          ),
        ),
      );
}

class _StatusBarIconButton extends StatelessWidget {
  final FocusNode? focusNode;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color iconColor;
  final Color? badgeColor;

  const _StatusBarIconButton({
    this.focusNode,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor = _statusBarGlyphColor,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return _StatusBarActionSurface(
      focusNode: focusNode,
      tooltip: tooltip,
      onPressed: onPressed,
      badgeColor: badgeColor,
      child: Icon(
        icon,
        size: _statusBarGlyphSize,
        color: iconColor,
      ),
    );
  }
}

class _StatusBarActionSurface extends StatefulWidget {
  final FocusNode? focusNode;
  final Widget child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? badgeColor;

  const _StatusBarActionSurface({
    this.focusNode,
    required this.child,
    this.onPressed,
    this.tooltip,
    this.badgeColor,
  });

  @override
  State<_StatusBarActionSurface> createState() =>
      _StatusBarActionSurfaceState();
}

class _StatusBarActionSurfaceState extends State<_StatusBarActionSurface> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final intensityFactor = context.select<SettingsService, double>(
      (settings) =>
          settings.homeDockGlassIntensityPercent.clamp(0, 100) / 100.0,
    );
    final content = SizedBox(
      width: _statusBarActionExtent,
      height: _statusBarActionExtent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: widget.onPressed != null
                ? TextButton(
                    focusNode: widget.focusNode,
                    onPressed: widget.onPressed,
                    style: _statusBarCompactButtonStyle(intensityFactor),
                    child: widget.child,
                  )
                : DecoratedBox(
                    decoration: _statusBarSurfaceDecoration(intensityFactor),
                    child: Center(child: widget.child),
                  ),
          ),
          if (widget.badgeColor != null)
            Positioned(
              right: 1,
              bottom: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.badgeColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _statusBarBaseSurface.withOpacity(0.88),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const SizedBox(width: 12, height: 12),
              ),
            ),
        ],
      ),
    );
    if (widget.tooltip == null) {
      return content;
    }
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: true,
      onFocusChange: (hasFocus) {
        if (_focused == hasFocus) {
          return;
        }
        setState(() => _focused = hasFocus);
        _syncTooltipVisibility();
      },
      child: MouseRegion(
        onEnter: (_) {
          if (_hovered) {
            return;
          }
          setState(() => _hovered = true);
          _syncTooltipVisibility();
        },
        onExit: (_) {
          if (!_hovered) {
            return;
          }
          setState(() => _hovered = false);
          _syncTooltipVisibility();
        },
        child: Tooltip(
          key: _tooltipKey,
          message: widget.tooltip!,
          triggerMode: TooltipTriggerMode.manual,
          waitDuration: Duration.zero,
          showDuration: const Duration(days: 1),
          child: content,
        ),
      ),
    );
  }

  void _syncTooltipVisibility() {
    if (widget.tooltip == null) {
      return;
    }
    if (_focused || _hovered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !(_focused || _hovered)) {
          return;
        }
        _tooltipKey.currentState?.ensureTooltipVisible();
      });
      return;
    }
    Tooltip.dismissAllToolTips();
  }
}

TextStyle _scaledStatusBarTextStyle(
  BuildContext context, {
  required double scale,
}) {
  final baseStyle = Theme.of(context).textTheme.titleLarge!;
  return baseStyle.copyWith(
    fontSize: (baseStyle.fontSize ?? 22) * scale,
    shadows: const [
      Shadow(
        color: Colors.black54,
        offset: Offset(0, 2),
        blurRadius: 8,
      )
    ],
  );
}

const double _statusBarActionSpacing = 12;
const double _statusBarActionExtent = 50;
const double _statusBarGlyphSize = 21;
const double _statusBarRamChipLeadingWidthCompact = 128;
const double _statusBarRamChipLeadingWidthRegular = 142;
const Color _statusBarGlyphColor = Color(0xFFF5F8FF);
const Color _statusBarBaseSurface = Color(0xFF132134);
const Color _statusBarBaseFocusedSurface = Color(0xFF1D314D);

ButtonStyle _statusBarCompactButtonStyle(double intensityFactor) {
  return ButtonStyle(
    minimumSize: WidgetStateProperty.all(Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    padding: WidgetStateProperty.all(EdgeInsets.zero),
    foregroundColor: WidgetStateProperty.all(_statusBarGlyphColor),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.focused)
          ? _statusBarBaseFocusedSurface.withOpacity(
              _statusBarFocusedFillOpacity(intensityFactor),
            )
          : _statusBarBaseSurface.withOpacity(
              _statusBarSurfaceFillOpacity(intensityFactor),
            );
    }),
    overlayColor: WidgetStateProperty.all(Colors.white10),
    shape: WidgetStateProperty.resolveWith(
      (states) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: states.contains(WidgetState.focused)
              ? Colors.white.withOpacity(0.92)
              : Colors.white.withOpacity(
                  _statusBarSurfaceBorderOpacity(intensityFactor),
                ),
          width: states.contains(WidgetState.focused) ? 2.0 : 1.15,
        ),
      ),
    ),
  );
}

Decoration _statusBarSurfaceDecoration(double intensityFactor) {
  return ShapeDecoration(
    color: _statusBarBaseSurface.withOpacity(
      _statusBarSurfaceFillOpacity(intensityFactor),
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Colors.white.withOpacity(
          _statusBarSurfaceBorderOpacity(intensityFactor),
        ),
        width: 1.15,
      ),
    ),
  );
}

double _statusBarSurfaceFillOpacity(double intensityFactor) =>
    0.10 + (0.12 * intensityFactor);

double _statusBarFocusedFillOpacity(double intensityFactor) =>
    0.20 + (0.16 * intensityFactor);

double _statusBarSurfaceBorderOpacity(double intensityFactor) =>
    0.16 + (0.12 * intensityFactor);
