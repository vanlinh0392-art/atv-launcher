import 'dart:async';

import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class DiagnosticsPanelPage extends StatefulWidget {
  static const String routeName = "diagnostics_panel";
  final FocusNode? primaryFocusNode;

  const DiagnosticsPanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<DiagnosticsPanelPage> createState() => _DiagnosticsPanelPageState();
}

class _DiagnosticsPanelPageState extends State<DiagnosticsPanelPage> {
  static const String _reportDebugLabel = 'diagnostics_report_section';
  final ScrollController _reportScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SystemBridgeService>().refreshFull();
    });
  }

  @override
  void dispose() {
    _reportScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bridgeService = context.read<SystemBridgeService>();
    final viewSize = MediaQuery.sizeOf(context);
    final report = context.select<SystemBridgeService, String>(
      (service) => service.diagnosticsReport,
    );
    final reportViewportHeight =
        (viewSize.height * 0.5).clamp(220.0, 420.0).toDouble();

    return ListView(
      key: const PageStorageKey<String>(DiagnosticsPanelPage.routeName),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        SettingsSurfaceCard(
          padding: TvDrawerTokens.surfacePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsAdaptiveGrid(
                spacing: 8,
                runSpacing: TvDrawerTokens.rowSpacing,
                minChildWidth: 240,
                maxColumns: 2,
                children: [
                  _buildCompactActionCard(
                    key: const Key('diagnostics_refresh_button'),
                    focusNode: widget.primaryFocusNode,
                    title: localizations.refreshLabel,
                    icon: Icons.refresh,
                    onPressed: () async => bridgeService.refreshFull(),
                  ),
                  _buildCompactActionCard(
                    key: const Key('diagnostics_copy_button'),
                    title: localizations.copyReport,
                    icon: Icons.copy_outlined,
                    onPressed: () async =>
                        Clipboard.setData(ClipboardData(text: report)),
                  ),
                ],
              ),
              const SizedBox(height: TvDrawerTokens.rowSpacing),
              _DiagnosticsReportSection(
                report: report,
                viewportHeight: reportViewportHeight,
                scrollController: _reportScrollController,
                debugLabel: _reportDebugLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionCard({
    Key? key,
    FocusNode? focusNode,
    SettingsBoundaryMoveHandler? onMoveUpAtBoundary,
    required String title,
    required IconData icon,
    required Future<void> Function()? onPressed,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58.0),
      child: SettingsActionCard(
        key: key,
        focusNode: focusNode,
        onMoveUpAtBoundary: onMoveUpAtBoundary,
        title: title,
        icon: icon,
        focusEmphasis: 1.16,
        onPressed: onPressed,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        titleMaxLines: 1,
        iconSize: 20,
        trailingIconSize: 20,
      ),
    );
  }
}

class _DiagnosticsReportSection extends StatefulWidget {
  final String report;
  final double viewportHeight;
  final ScrollController scrollController;
  final String debugLabel;

  const _DiagnosticsReportSection({
    required this.report,
    required this.viewportHeight,
    required this.scrollController,
    required this.debugLabel,
  });

  @override
  State<_DiagnosticsReportSection> createState() =>
      _DiagnosticsReportSectionState();
}

class _DiagnosticsReportSectionState extends State<_DiagnosticsReportSection> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: widget.debugLabel);
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
        canRequestFocus: widget.report.trim().isNotEmpty,
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() => _focused = value);
          }
        },
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _scrollReport(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (_scrollReport(-1)) {
              return KeyEventResult.handled;
            }
            _focusNode.focusInDirection(TraversalDirection.up);
            return KeyEventResult.handled;
          }
          if (isSettingsActivateKey(event.logicalKey)) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SettingsFocusFrame(
          key: const Key('diagnostics_report_section'),
          padding: EdgeInsets.zero,
          variant: SettingsFocusFrameVariant.rowOnly,
          focusEmphasis: 1.12,
          focused: _focused,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: Colors.white.withOpacity(0.035),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SizedBox(
                height: widget.viewportHeight,
                child: Scrollbar(
                  controller: widget.scrollController,
                  thumbVisibility: _focused,
                  child: SingleChildScrollView(
                    key: const Key('diagnostics_report_scrollable'),
                    controller: widget.scrollController,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SelectableText(
                        widget.report.isEmpty ? '-' : widget.report,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.34),
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

  bool _scrollReport(int directionSign) {
    if (!widget.scrollController.hasClients) {
      return false;
    }
    final position = widget.scrollController.position;
    final step = position.hasViewportDimension
        ? (position.viewportDimension * 0.72).clamp(120.0, 280.0).toDouble()
        : (widget.viewportHeight * 0.72).clamp(120.0, 280.0).toDouble();
    final targetOffset = (position.pixels + (step * directionSign))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((targetOffset - position.pixels).abs() < 0.5) {
      return false;
    }
    unawaited(
      position.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 96),
        curve: Curves.easeOutCubic,
      ),
    );
    return true;
  }
}
