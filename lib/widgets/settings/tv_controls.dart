import 'package:flauncher/widgets/ensure_visible.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_chrome.dart';

bool isSettingsActivateKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.space;

class SettingsChoiceOption<T> {
  final T value;
  final String label;

  const SettingsChoiceOption({
    required this.value,
    required this.label,
  });
}

class SettingsActionCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Future<void> Function()? onPressed;
  final bool autofocus;

  const SettingsActionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onPressed,
    this.autofocus = false,
  });

  @override
  State<SettingsActionCard> createState() => _SettingsActionCardState();
}

class _SettingsActionCardState extends State<SettingsActionCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.12,
        child: FocusableActionDetector(
          autofocus: widget.autofocus,
          onShowFocusHighlight: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
            }
          },
          child: SettingsFocusFrame(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _focused ? 1 : 0.96,
              child: TextButton(
                onPressed: widget.onPressed == null
                    ? null
                    : () => widget.onPressed!.call(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.icon, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
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
  });

  @override
  State<SettingsChoiceCard<T>> createState() => _SettingsChoiceCardState<T>();
}

class _SettingsChoiceCardState<T> extends State<SettingsChoiceCard<T>> {
  late List<FocusNode> _optionFocusNodes;
  bool _hasFocus = false;
  int _lastFocusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _optionFocusNodes = _buildOptionFocusNodes();
  }

  @override
  void didUpdateWidget(covariant SettingsChoiceCard<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EnsureVisible(
        alignment: 0.12,
        child: Focus(
          canRequestFocus: false,
          onFocusChange: (value) {
            if (_hasFocus != value) {
              setState(() => _hasFocus = value);
            }
          },
          onKeyEvent: (_, event) => _handleContainerKeyEvent(event),
          child: Focus(
            focusNode: widget.focusNode,
            child: SettingsFocusFrame(
              key: widget.selectorKey,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hasFocus ? 1 : 0.96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(widget.icon, color: Colors.white70),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: Theme.of(context).textTheme.bodyLarge,
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
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          List<Widget>.generate(widget.options.length, (index) {
                        final option = widget.options[index];
                        final buttonKeyPrefix = widget.optionKeyPrefix;
                        final button = SettingsControlButton(
                          focusNode: _optionFocusNodes[index],
                          selected: option.value == widget.value,
                          onPressed: () => widget.onChanged(option.value),
                          onMoveBackOnLeft: index == 0
                              ? () => widget.focusNode?.requestFocus()
                              : null,
                          onFocused: () => _lastFocusedIndex = index,
                          child: Text(option.label),
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
                      }),
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
          debugLabel:
              '${widget.focusNode?.debugLabel ?? widget.title}_option_$index',
        ),
        growable: false,
      );

  KeyEventResult _handleContainerKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || widget.focusNode?.hasFocus != true) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        isSettingsActivateKey(event.logicalKey)) {
      _focusSelectedOption();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusSelectedOption() {
    if (_optionFocusNodes.isEmpty) {
      return;
    }
    final selectedIndex =
        widget.options.indexWhere((option) => option.value == widget.value);
    final targetIndex = selectedIndex >= 0
        ? selectedIndex
        : _lastFocusedIndex.clamp(0, _optionFocusNodes.length - 1);
    _optionFocusNodes[targetIndex].requestFocus();
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
  });

  @override
  State<SettingsStepperCard> createState() => _SettingsStepperCardState();
}

class _SettingsStepperCardState extends State<SettingsStepperCard> {
  late final FocusNode _decreaseFocusNode;
  late final FocusNode _increaseFocusNode;
  bool _hasFocus = false;
  int _lastFocusedActionIndex = 0;

  @override
  void initState() {
    super.initState();
    final debugBase = widget.focusNode?.debugLabel ?? widget.title;
    _decreaseFocusNode = FocusNode(debugLabel: '${debugBase}_decrease');
    _increaseFocusNode = FocusNode(debugLabel: '${debugBase}_increase');
  }

  @override
  void dispose() {
    _decreaseFocusNode.dispose();
    _increaseFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDecrease =
        widget.onChanged != null && widget.value > widget.minimum;
    final canIncrease =
        widget.onChanged != null && widget.value < widget.maximum;
    return EnsureVisible(
      alignment: 0.12,
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (value) {
          if (_hasFocus != value) {
            setState(() => _hasFocus = value);
          }
        },
        onKeyEvent: (_, event) => _handleContainerKeyEvent(event),
        child: Focus(
          focusNode: widget.focusNode,
          child: SettingsFocusFrame(
            key: widget.selectorKey,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hasFocus ? 1 : 0.96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(widget.icon, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.bodyLarge,
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _wrapStepperButton(
                        suffix: 'decrease',
                        child: SettingsControlButton(
                          focusNode: _decreaseFocusNode,
                          selected: false,
                          enabled: canDecrease,
                          onPressed: canDecrease
                              ? () => _shiftValue(-widget.step)
                              : null,
                          onMoveBackOnLeft: () =>
                              widget.focusNode?.requestFocus(),
                          onMoveNextOnRight: () =>
                              _increaseFocusNode.requestFocus(),
                          onFocused: () => _lastFocusedActionIndex = 0,
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
                          onPressed: canIncrease
                              ? () => _shiftValue(widget.step)
                              : null,
                          onFocused: () => _lastFocusedActionIndex = 1,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
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
    if (event is! KeyDownEvent || widget.focusNode?.hasFocus != true) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        isSettingsActivateKey(event.logicalKey)) {
      _focusActiveAction();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusActiveAction() {
    final preferredIndex = _lastFocusedActionIndex;
    if (preferredIndex == 0 && widget.value > widget.minimum) {
      _decreaseFocusNode.requestFocus();
      return;
    }
    if (preferredIndex == 1 && widget.value < widget.maximum) {
      _increaseFocusNode.requestFocus();
      return;
    }
    if (widget.value > widget.minimum) {
      _decreaseFocusNode.requestFocus();
      return;
    }
    if (widget.value < widget.maximum) {
      _increaseFocusNode.requestFocus();
    }
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
}

class SettingsControlButton extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
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
            widget.onMoveBackOnLeft != null) {
          widget.onMoveBackOnLeft!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.onMoveNextOnRight != null) {
          widget.onMoveNextOnRight!.call();
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
