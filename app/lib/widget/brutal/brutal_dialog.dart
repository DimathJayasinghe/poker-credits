import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';

/// A hairline-bordered dialog on a flat surface. Returns what [actions] pop with.
Future<T?> showBrutalDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: BrutalColors.dark.paper.withValues(alpha: 0.7),
    builder: (context) => BrutalDialog(title: title, content: content, actions: actions),
  );
}

/// Dialog panel; use [showBrutalDialog] to show it.
class BrutalDialog extends StatelessWidget {
  const BrutalDialog({super.key, required this.title, required this.content, required this.actions});

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.all(BrutalMetrics.gapM),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: title,
          explicitChildNodes: true,
          child: BrutalCard(
            header: title,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // At a huge text size the message may not push the buttons off the screen.
                Flexible(child: SingleChildScrollView(child: content)),
                const SizedBox(height: BrutalMetrics.gapM),
                Wrap(spacing: BrutalMetrics.gapM, runSpacing: BrutalMetrics.gapS, alignment: WrapAlignment.end, children: actions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience for a confirm dialog: returns true when confirmed.
Future<bool> confirmBrutal({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool danger = false,
}) async {
  final result = await showBrutalDialog<bool>(
    context: context,
    title: title,
    content: Text(message, style: TextStyle(fontSize: 16, color: BrutalTheme.of(context).colors.ink)),
    actions: <Widget>[
      Builder(
        builder: (context) => BrutalButton(label: cancelLabel, onPressed: () => Navigator.of(context).pop(false)),
      ),
      Builder(
        builder: (context) => BrutalButton(
          label: confirmLabel,
          kind: danger ? BrutalButtonKind.danger : BrutalButtonKind.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
    ],
  );
  return result ?? false;
}
