import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_chrome.dart';

bool isSettingsActivateKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.space;

typedef SettingsBoundaryMoveHandler = bool Function();

class SettingsChoiceOption<T> {
  final T value;
  final String label;
  final Color? swatchColor;

  const SettingsChoiceOption({
    required this.value,
    required this.label,
    this.swatchColor,
  });
}

class SettingsActionCard extends StatefulWidget {
  final FocusNode? focusNode;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Future<void> Function()? onPressed;
  final bool autofocus;
  final double focusEmphasis;
  final SettingsBoundaryMoveHandler? onMoveUpAtBoundary;

  const SettingsActionCard({
    super.key,
    this.focusNode,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onPressed,
    this.autofocus = false,
    this.focusEmphasis = 1.3,
    this.onMoveUpAtBoundary,
  });

  @override
  State<SettingsActionCard> createState() => _SettingsActionCardState();
}

class _SettingsActionCardState extends State<SettingsActionCard> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _configureFocusNode();
  }

  @override
  void didUpdateWidget(covariant SettingsActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) {
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
    final enabled = widget.onPressed != null;
    final iconColor =
        enabled ? (_focused ? Colors.white : Colors.white70) : Colors.white38;
    final titleColor = enabled
        ? (_focused ? Colors.white : Colors.white.withOpacity(0.96))
        : Colors.white38;
    final subtitleColor = enabled
        ? (_focused ? Colors.white.withOpacity(0.86) : Colors.white70)
        : Colors.white38;
    return EnsureVisible(
      alignment: EnsureVisible.settingsAlignment,
      settleFrameCount: 1,
      preferImmediate: true,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: enabled,
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() => _focused = value);
          }
        },
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          final direction = _verticalDirectionForKey(event.logicalKey);
          if (direction != null) {
            if (direction == TraversalDirection.up &&
                widget.onMoveUpAtBoundary != null &&
                widget.onMoveUpAtBoundary!.call()) {
              return KeyEventResult.handled;
            }
            if (!moveSettingsVerticalFocus(
              direction: direction,
              localNodes: <FocusNode>[_focusNode],
            )) {
              if (direction == TraversalDirection.up &&
                  focusNearestSettingsSummaryAbove(_focusNode)) {
                return KeyEventResult.handled;
              }
              _focusNode.focusInDirection(direction);
            }
            return KeyEventResult.handled;
          }
          if (isSettingsActivateKey(event.logicalKey) && enabled) {
            widget.onPressed?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SettingsFocusFrame(
          padding: EdgeInsets.zero,
          variant: SettingsFocusFrameVariant.rowOnly,
          focusEmphasis: widget.focusEmphasis,
          focused: _focused,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => widget.onPressed!.call() : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: enabled ? (_focused ? 1 : 0.97) : 0.46,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: widget.subtitle == null
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Icon(widget.icon, color: iconColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: widget.subtitle == null
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: titleColor,
                                      fontWeight: _focused
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: subtitleColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.chevron_right, color: iconColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _configureFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ??
        FocusNode(
          debugLabel: 'settings_action_${widget.title}'.replaceAll(' ', '_'),
        );
  }
}

class SettingsChoiceCard<T> extends StatefulWidget {
  final Key? selectorKey;
  final String? optionKeyPrefix;
  final FocusNode? focusNode;
  final String title;
  final String subtitle;
  final IconData icon;
  final T value;
  final List<SettingsChoiceOption<T>> options;
  final String Function(T value) valueLabelBuilder;
  final ValueChanged<T> onChanged;
  final SettingsBoundaryMoveHandler? onMoveUpAtBoundary;

  const SettingsChoiceCard({
    super.key,
    this.selectorKey,
    this.optionKeyPrefix,
    this.focusNode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.options,
    required this.valueLabelBuilder,
    required this.onChanged,
    this.onMoveUpAtBoundary,
  });

  @override
  State<SettingsChoiceCard<T>> createState() => _SettingsChoiceCardState<T>();
}

class _SettingsChoiceCardState<T> extends State<SettingsChoiceCard<T>> {
  late final FocusNode _rowFocusNode;
  late final bool _ownsRowFocusNode;
  late List<FocusNode> _optionFocusNodes;
  bool _hasFocus = false;
  bool _skipAutoEnterOnNextRowFocus = false;

  @override
  void initState() {
    super.initState();
    _ownsRowFocusNode = widget.focusNode == null;
    final debugBase = _rowDebugBase();
    _rowFocusNode =
        widget.focusNode ?? FocusNode(debugLabel: '${debugBase}_row');
    _optionFocusNodes = _buildOptionFocusNodes();
  }

  @override
  void didUpdateWidget(covariant SettingsChoiceCard<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length ||
        oldWidget.optionKeyPrefix != widget.optionKeyPrefix ||
        oldWidget.focusNode != widget.focusNode) {
      for (final node in _optionFocusNodes) {
        node.dispose();
      }
      _optionFocusNodes = _buildOptionFocusNodes();
    }
  }

  @override
  void dispose() {
    for (final node in _optionFocusNodes) {
      node.dispose();
    }
    if (_ownsRowFocusNode) {
      _rowFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: EnsureVisible.settingsAlignment,
        settleFrameCount: 1,
        preferImmediate: true,
        child: Focus(
          canRequestFocus: false,
          onFocusChange: (value) {
            if (_hasFocus != value) {
              setState(() => _hasFocus = value);
            }
          },
          onKeyEvent: (_, event) => _handleContainerKeyEvent(event),
          child: Focus(
            focusNode: _rowFocusNode,
            onFocusChange: _handleRowFocusChange,
            child: SettingsFocusFrame(
              key: widget.selectorKey,
              variant: SettingsFocusFrameVariant.rowOnly,
              focused: _hasFocus,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hasFocus ? 1 : 0.96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          widget.icon,
                          color: _hasFocus ? Colors.white : Colors.white70,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: _hasFocus
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.valueLabelBuilder(widget.value),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: _hasFocus
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.92),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    if (_hasFocus)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List<Widget>.generate(
                            widget.options.length,
                            (index) {
                              final option = widget.options[index];
                              final buttonKeyPrefix = widget.optionKeyPrefix;
                              final button = SettingsControlButton(
                                focusNode: _optionFocusNodes[index],
                                selected: option.value == widget.value,
                                onPressed: () => widget.onChanged(option.value),
                                onFocused: _ensureRowVisible,
                                onMovePreviousOnLeft: index > 0
                                    ? () => _optionFocusNodes[index - 1]
                                        .requestFocus()
                                    : null,
                                onMoveBackOnLeft: index == 0
                                    ? _focusRowWithoutAutoEnter
                                    : null,
                                onMoveNextOnRight:
                                    index < widget.options.length - 1
                                        ? () => _optionFocusNodes[index + 1]
                                            .requestFocus()
                                        : null,
                                child: _ChoiceOptionContent(option: option),
                              );
                              if (buttonKeyPrefix == null) {
                                return button;
                              }
                              return KeyedSubtree(
                                key: ValueKey<String>(
                                  '${buttonKeyPrefix}_${option.value}',
                                ),
                                child: button,
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  List<FocusNode> _buildOptionFocusNodes() => List<FocusNode>.generate(
        widget.options.length,
        (index) => FocusNode(
          debugLabel: '${_rowDebugBase()}_option_$index',
        ),
        growable: false,
      );

  KeyEventResult _handleContainerKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !_hasFocus) {
      return KeyEventResult.ignored;
    }
    final direction = _verticalDirectionForKey(event.logicalKey);
    if (direction != null) {
      if (direction == TraversalDirection.up &&
          widget.onMoveUpAtBoundary != null &&
          widget.onMoveUpAtBoundary!.call()) {
        return KeyEventResult.handled;
      }
      if (!_moveVerticalFocusDirectly(direction)) {
        if (direction == TraversalDirection.up &&
            focusNearestSettingsSummaryAbove(_rowFocusNode)) {
          return KeyEventResult.handled;
        }
        _moveFocusBetweenRows(direction);
      }
      return KeyEventResult.handled;
    }
    if (!_rowFocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        isSettingsActivateKey(event.logicalKey)) {
      _focusSelectedOption();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleRowFocusChange(bool hasFocus) {
    if (!hasFocus) {
      return;
    }
    if (_skipAutoEnterOnNextRowFocus) {
      _skipAutoEnterOnNextRowFocus = false;
      _ensureRowVisible();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rowFocusNode.hasFocus) {
        return;
      }
      _focusSelectedOption();
      _ensureRowVisible();
    });
  }

  void _focusRowWithoutAutoEnter() {
    _skipAutoEnterOnNextRowFocus = true;
    _rowFocusNode.requestFocus();
  }

  void _focusSelectedOption() {
    if (_optionFocusNodes.isEmpty) {
      return;
    }
    final selectedIndex = widget.options.indexWhere(
      (option) => option.value == widget.value,
    );
    _optionFocusNodes[(selectedIndex < 0 ? 0 : selectedIndex)].requestFocus();
  }

  void _ensureRowVisible() {
    final targetContext = widget.selectorKey is GlobalKey
        ? (widget.selectorKey! as GlobalKey).currentContext
        : null;
    EnsureVisible.scheduleEnsureVisible(
      targetContext ?? context,
      alignment: EnsureVisible.settingsAlignment,
      remainingPasses: 1,
      preferImmediate: true,
    );
  }

  void _moveFocusBetweenRows(TraversalDirection direction) {
    _focusRowWithoutAutoEnter();
    Future<void>.microtask(() {
      if (!mounted || !_rowFocusNode.hasFocus) {
        return;
      }
      _rowFocusNode.focusInDirection(direction);
    });
  }

  bool _moveVerticalFocusDirectly(TraversalDirection direction) {
    return _moveVerticalFocusOutsideCluster(
      direction: direction,
      localNodes: <FocusNode>{
        _rowFocusNode,
        ..._optionFocusNodes,
      },
    );
  }

  String _rowDebugBase() {
    final focusLabel = widget.focusNode?.debugLabel?.trim() ?? '';
    if (focusLabel.isNotEmpty) {
      return focusLabel.replaceAll(' ', '_');
    }
    final optionKeyPrefix = widget.optionKeyPrefix?.trim() ?? '';
    if (optionKeyPrefix.isNotEmpty) {
      return optionKeyPrefix.replaceFirst(RegExp(r'_option$'), '');
    }
    return widget.title.replaceAll(' ', '_');
  }
}

class SettingsStepperCard extends StatefulWidget {
  final Key? selectorKey;
  final String? buttonKeyPrefix;
  final FocusNode? focusNode;
  final String title;
  final String subtitle;
  final IconData icon;
  final int value;
  final int minimum;
  final int maximum;
  final int step;
  final String Function(int value) valueLabelBuilder;
  final ValueChanged<int>? onChanged;
  final SettingsBoundaryMoveHandler? onMoveUpAtBoundary;

  const SettingsStepperCard({
    super.key,
    this.selectorKey,
    this.buttonKeyPrefix,
    this.focusNode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.step,
    required this.valueLabelBuilder,
    required this.onChanged,
    this.onMoveUpAtBoundary,
  });

  @override
  State<SettingsStepperCard> createState() => _SettingsStepperCardState();
}

class _SettingsStepperCardState extends State<SettingsStepperCard> {
  late final FocusNode _rowFocusNode;
  late final bool _ownsRowFocusNode;
  late final FocusNode _decreaseFocusNode;
  late final FocusNode _increaseFocusNode;
  bool _hasFocus = false;
  bool _skipAutoEnterOnNextRowFocus = false;

  @override
  void initState() {
    super.initState();
    _ownsRowFocusNode = widget.focusNode == null;
    final debugBase = _rowDebugBase();
    _rowFocusNode =
        widget.focusNode ?? FocusNode(debugLabel: '${debugBase}_row');
    _decreaseFocusNode = FocusNode(debugLabel: '${debugBase}_decrease');
    _increaseFocusNode = FocusNode(debugLabel: '${debugBase}_increase');
  }

  @override
  void dispose() {
    _decreaseFocusNode.dispose();
    _increaseFocusNode.dispose();
    if (_ownsRowFocusNode) {
      _rowFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDecrease =
        widget.onChanged != null && widget.value > widget.minimum;
    final canIncrease =
        widget.onChanged != null && widget.value < widget.maximum;
    return EnsureVisible(
      alignment: EnsureVisible.settingsAlignment,
      settleFrameCount: 1,
      preferImmediate: true,
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (value) {
          if (_hasFocus != value) {
            setState(() => _hasFocus = value);
          }
        },
        onKeyEvent: (_, event) => _handleContainerKeyEvent(event),
        child: Focus(
          focusNode: _rowFocusNode,
          onFocusChange: _handleRowFocusChange,
          child: SettingsFocusFrame(
            key: widget.selectorKey,
            variant: SettingsFocusFrameVariant.rowOnly,
            focused: _hasFocus,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hasFocus ? 1 : 0.96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        widget.icon,
                        color: _hasFocus ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    fontWeight: _hasFocus
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.valueLabelBuilder(widget.value),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: _hasFocus
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.92),
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                  if (_hasFocus)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        children: [
                          _wrapStepperButton(
                            suffix: 'decrease',
                            child: SettingsControlButton(
                              focusNode: _decreaseFocusNode,
                              selected: false,
                              enabled: canDecrease,
                              onFocused: _ensureRowVisible,
                              onPressed: canDecrease
                                  ? () => _shiftValue(-widget.step)
                                  : null,
                              onMoveBackOnLeft: _focusRowWithoutAutoEnter,
                              onMoveNextOnRight: () =>
                                  _increaseFocusNode.requestFocus(),
                              child: const Icon(Icons.remove),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                              child: Text(
                                widget.valueLabelBuilder(widget.value),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _wrapStepperButton(
                            suffix: 'increase',
                            child: SettingsControlButton(
                              focusNode: _increaseFocusNode,
                              selected: false,
                              enabled: canIncrease,
                              onFocused: _ensureRowVisible,
                              onPressed: canIncrease
                                  ? () => _shiftValue(widget.step)
                                  : null,
                              onMovePreviousOnLeft: canDecrease
                                  ? () => _decreaseFocusNode.requestFocus()
                                  : null,
                              onMoveBackOnLeft: !canDecrease
                                  ? _focusRowWithoutAutoEnter
                                  : null,
                              child: const Icon(Icons.add),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleContainerKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !_hasFocus) {
      return KeyEventResult.ignored;
    }
    final direction = _verticalDirectionForKey(event.logicalKey);
    if (direction != null) {
      if (direction == TraversalDirection.up &&
          widget.onMoveUpAtBoundary != null &&
          widget.onMoveUpAtBoundary!.call()) {
        return KeyEventResult.handled;
      }
      if (!_moveVerticalFocusDirectly(direction)) {
        if (direction == TraversalDirection.up &&
            focusNearestSettingsSummaryAbove(_rowFocusNode)) {
          return KeyEventResult.handled;
        }
        _moveFocusBetweenRows(direction);
      }
      return KeyEventResult.handled;
    }
    if (!_rowFocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        isSettingsActivateKey(event.logicalKey)) {
      _focusActiveAction();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleRowFocusChange(bool hasFocus) {
    if (!hasFocus) {
      return;
    }
    if (_skipAutoEnterOnNextRowFocus) {
      _skipAutoEnterOnNextRowFocus = false;
      _ensureRowVisible();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rowFocusNode.hasFocus) {
        return;
      }
      _focusActiveAction();
      _ensureRowVisible();
    });
  }

  void _focusRowWithoutAutoEnter() {
    _skipAutoEnterOnNextRowFocus = true;
    _rowFocusNode.requestFocus();
  }

  void _focusActiveAction() {
    if (widget.value > widget.minimum) {
      _decreaseFocusNode.requestFocus();
      return;
    }
    if (widget.value < widget.maximum) {
      _increaseFocusNode.requestFocus();
    }
  }

  void _ensureRowVisible() {
    final targetContext = widget.selectorKey is GlobalKey
        ? (widget.selectorKey! as GlobalKey).currentContext
        : null;
    EnsureVisible.scheduleEnsureVisible(
      targetContext ?? context,
      alignment: EnsureVisible.settingsAlignment,
      remainingPasses: 1,
      preferImmediate: true,
    );
  }

  void _moveFocusBetweenRows(TraversalDirection direction) {
    _focusRowWithoutAutoEnter();
    Future<void>.microtask(() {
      if (!mounted || !_rowFocusNode.hasFocus) {
        return;
      }
      _rowFocusNode.focusInDirection(direction);
    });
  }

  bool _moveVerticalFocusDirectly(TraversalDirection direction) {
    return _moveVerticalFocusOutsideCluster(
      direction: direction,
      localNodes: <FocusNode>{
        _rowFocusNode,
        _decreaseFocusNode,
        _increaseFocusNode,
      },
    );
  }

  Widget _wrapStepperButton({
    required String suffix,
    required Widget child,
  }) {
    final prefix = widget.buttonKeyPrefix;
    if (prefix == null) {
      return child;
    }
    return KeyedSubtree(
      key: ValueKey<String>('${prefix}_$suffix'),
      child: child,
    );
  }

  bool _shiftValue(int delta) {
    if (widget.onChanged == null) {
      return false;
    }
    final next =
        (widget.value + delta).clamp(widget.minimum, widget.maximum).toInt();
    if (next != widget.value) {
      widget.onChanged!(next);
      return true;
    }
    return false;
  }

  String _rowDebugBase() {
    final focusLabel = widget.focusNode?.debugLabel?.trim() ?? '';
    if (focusLabel.isNotEmpty) {
      return focusLabel.replaceAll(' ', '_');
    }
    final buttonKeyPrefix = widget.buttonKeyPrefix?.trim() ?? '';
    if (buttonKeyPrefix.isNotEmpty) {
      return buttonKeyPrefix;
    }
    return widget.title.replaceAll(' ', '_');
  }
}

TraversalDirection? _verticalDirectionForKey(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowUp) {
    return TraversalDirection.up;
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    return TraversalDirection.down;
  }
  return null;
}

bool moveSettingsVerticalFocus({
  required TraversalDirection direction,
  required Iterable<FocusNode> localNodes,
}) {
  final localNodeSet = localNodes.toSet();
  final current = FocusManager.instance.primaryFocus;
  if (current == null || !localNodeSet.contains(current)) {
    return false;
  }

  final scope = current.nearestScope;
  final descendants = scope?.traversalDescendants.toList();
  if (descendants == null || descendants.isEmpty) {
    return false;
  }

  final searcher = NodeSearcher(direction);
  final candidates = descendants.where((node) {
    if (localNodeSet.contains(node)) {
      return false;
    }
    if (!node.canRequestFocus) {
      return false;
    }
    return node.context != null;
  }).toList(growable: false);
  if (candidates.isEmpty) {
    return false;
  }

  final matchingCandidates = searcher.findCandidates(candidates, current);
  if (matchingCandidates.isEmpty) {
    return false;
  }

  searcher.findBestFocusNode(matchingCandidates, current).requestFocus();
  return true;
}

bool focusNearestSettingsSummaryAbove(FocusNode currentNode) {
  final scope = currentNode.nearestScope;
  final descendants = scope?.traversalDescendants.toList();
  if (descendants == null || descendants.isEmpty) {
    return false;
  }

  final summaryCandidates = descendants.where((node) {
    if (!node.canRequestFocus || node.context == null) {
      return false;
    }
    final label = node.debugLabel?.trim() ?? '';
    return label.contains('_summary_') || label.startsWith('settings_metric_');
  }).toList(growable: false);
  if (summaryCandidates.isEmpty) {
    return false;
  }

  final searcher = NodeSearcher(TraversalDirection.up);
  final matchingCandidates =
      searcher.findCandidates(summaryCandidates, currentNode);
  if (matchingCandidates.isEmpty) {
    return false;
  }

  searcher.findBestFocusNode(matchingCandidates, currentNode).requestFocus();
  return true;
}

bool focusSettingsNodeByDebugLabel(
  FocusNode currentNode,
  String debugLabel,
) {
  final scope = currentNode.nearestScope;
  final descendants = scope?.traversalDescendants.toList();
  if (descendants == null || descendants.isEmpty) {
    return false;
  }

  for (final node in descendants) {
    if (!node.canRequestFocus || node.context == null) {
      continue;
    }
    if ((node.debugLabel?.trim() ?? '') == debugLabel) {
      node.requestFocus();
      return true;
    }
  }
  return false;
}

bool focusCurrentSettingsNodeByDebugLabel(String debugLabel) {
  final currentNode = FocusManager.instance.primaryFocus;
  if (currentNode == null) {
    return false;
  }
  return focusSettingsNodeByDebugLabel(currentNode, debugLabel);
}

bool _moveVerticalFocusOutsideCluster({
  required TraversalDirection direction,
  required Set<FocusNode> localNodes,
}) =>
    moveSettingsVerticalFocus(
      direction: direction,
      localNodes: localNodes,
    );

class _ChoiceOptionContent<T> extends StatelessWidget {
  final SettingsChoiceOption<T> option;

  const _ChoiceOptionContent({
    required this.option,
  });

  @override
  Widget build(BuildContext context) {
    if (option.swatchColor == null) {
      return Text(option.label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: option.swatchColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.75),
              width: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(option.label)),
      ],
    );
  }
}

class SettingsControlButton extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
  final VoidCallback? onMovePreviousOnLeft;
  final VoidCallback? onMoveBackOnLeft;
  final VoidCallback? onMoveNextOnRight;
  final VoidCallback? onFocused;

  const SettingsControlButton({
    super.key,
    required this.focusNode,
    required this.child,
    required this.selected,
    this.enabled = true,
    this.onPressed,
    this.onMovePreviousOnLeft,
    this.onMoveBackOnLeft,
    this.onMoveNextOnRight,
    this.onFocused,
  });

  @override
  State<SettingsControlButton> createState() => _SettingsControlButtonState();
}

class _SettingsControlButtonState extends State<SettingsControlButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final chromeSpec = SettingsChromeSpec.of(context);
    final selected = widget.selected;
    final enabled = widget.enabled;
    final visuals = SettingsButtonStyles.resolveControlVisuals(
      chromeSpec,
      variant: selected
          ? SettingsButtonVariant.primary
          : SettingsButtonVariant.neutral,
      focused: _focused,
      enabled: enabled,
      selected: selected,
    );

    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: enabled,
      onFocusChange: (value) {
        if (_focused != value) {
          setState(() => _focused = value);
        }
        if (value) {
          widget.onFocused?.call();
        }
      },
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            widget.onMovePreviousOnLeft != null) {
          widget.onMovePreviousOnLeft!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            widget.onMoveBackOnLeft != null) {
          widget.onMoveBackOnLeft!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.onMoveNextOnRight != null) {
          widget.onMoveNextOnRight!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          return KeyEventResult.handled;
        }
        if (isSettingsActivateKey(event.logicalKey) && enabled) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          scale: visuals.scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: visuals.fillColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: visuals.borderColor,
                width: visuals.borderWidth,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: visuals.shadowColor,
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 110),
              opacity: visuals.contentOpacity,
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: Colors.white.withOpacity(enabled ? 0.96 : 0.42),
                    size: 20,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
