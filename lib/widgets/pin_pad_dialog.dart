import 'dart:math' as math;

import 'package:flauncher/models/app.dart';
import 'package:flauncher/providers/profile_security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

Future<bool> ensureSecurityAccess(
  BuildContext context, {
  required String title,
  required String description,
}) async {
  final service = context.read<ProfileSecurityService?>();
  if (service == null) {
    return true;
  }
  if (!service.requiresPinForSettingsAccess()) {
    return true;
  }

  final localizations = AppLocalizations.of(context)!;
  if (!service.hasPin) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.ownerPinRequiredMessage)),
    );
    return false;
  }

  final pin = await showPinPadDialog(
    context,
    title: title,
    description: description,
    confirmLabel: localizations.unlockAction,
  );
  if (pin == null) {
    return false;
  }
  if (service.unlockWithPin(pin)) {
    return true;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.invalidPinMessage)),
    );
  }
  return false;
}

Future<bool> ensureAppLaunchAccess(
  BuildContext context,
  App app, {
  String? title,
  String? description,
}) async {
  final service = context.read<ProfileSecurityService?>();
  if (service == null || service.canLaunchApp(app)) {
    return true;
  }
  final localizations = AppLocalizations.of(context)!;
  if (!service.hasPin) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.ownerPinRequiredMessage)),
    );
    return false;
  }
  final pin = await showPinPadDialog(
    context,
    title: title ?? localizations.unlockAppTitle,
    description: description ?? localizations.unlockAppDescription(app.name),
    confirmLabel: localizations.unlockAction,
  );
  if (pin == null) {
    return false;
  }
  if (service.unlockWithPin(pin)) {
    return true;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.invalidPinMessage)),
    );
  }
  return false;
}

Future<String?> showPinPadDialog(
  BuildContext context, {
  required String title,
  required String description,
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _PinPadDialog(
      title: title,
      description: description,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PinPadDialog extends StatefulWidget {
  final String title;
  final String description;
  final String confirmLabel;

  const _PinPadDialog({
    required this.title,
    required this.description,
    required this.confirmLabel,
  });

  @override
  State<_PinPadDialog> createState() => _PinPadDialogState();
}

class _PinPadDialogState extends State<_PinPadDialog> {
  final StringBuffer _pinBuffer = StringBuffer();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final pinLength = _pinBuffer.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalInset = constraints.maxWidth >= 1200 ? 220.0 : 24.0;
        final verticalInset = constraints.maxHeight >= 720 ? 40.0 : 20.0;
        final maxDialogWidth = math.min(
          620.0,
          math.max(320.0, constraints.maxWidth - (horizontalInset * 2)),
        );
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: horizontalInset,
            vertical: verticalInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxDialogWidth,
              maxHeight: math.max(
                360.0,
                constraints.maxHeight - (verticalInset * 2),
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D2036),
                    Color(0xFF122A45),
                    Color(0xFF091523),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x7A000000),
                    blurRadius: 40,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: LayoutBuilder(
                  builder: (context, dialogConstraints) {
                    final keypadWidth = math.min(
                      dialogConstraints.maxWidth,
                      520.0,
                    );
                    final buttonWidth = math.max(
                      88.0,
                      math.min(
                        160.0,
                        (keypadWidth - 24) / 3,
                      ),
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List<Widget>.generate(4, (index) {
                            final filled = index < pinLength;
                            return Container(
                              width: 24,
                              height: 24,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? const Color(0xFF8CCBFF)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: filled
                                      ? const Color(0xFF8CCBFF)
                                      : Colors.white38,
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: keypadWidth,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: <String>[
                              '1',
                              '2',
                              '3',
                              '4',
                              '5',
                              '6',
                              '7',
                              '8',
                              '9',
                              localizations.clearAction,
                              '0',
                              localizations.backspaceAction,
                            ]
                                .map((label) => _PinButton(
                                      width: buttonWidth,
                                      label: label,
                                      onPressed: () =>
                                          _handlePress(label, localizations),
                                    ))
                                .toList(growable: false),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(localizations.cancel),
                            ),
                            FilledButton(
                              onPressed: _pinBuffer.length == 4
                                  ? () => Navigator.of(context)
                                      .pop(_pinBuffer.toString())
                                  : null,
                              child: Text(widget.confirmLabel),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePress(String label, AppLocalizations localizations) {
    setState(() {
      if (label == localizations.clearAction) {
        _pinBuffer.clear();
        return;
      }
      if (label == localizations.backspaceAction) {
        if (_pinBuffer.isNotEmpty) {
          final current = _pinBuffer.toString();
          _pinBuffer
            ..clear()
            ..write(current.substring(0, current.length - 1));
        }
        return;
      }
      if (_pinBuffer.length >= 4) {
        return;
      }
      _pinBuffer.write(label);
    });
  }
}

class _PinButton extends StatelessWidget {
  final double width;
  final String label;
  final VoidCallback onPressed;

  const _PinButton({
    required this.width,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
