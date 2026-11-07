import 'package:flutter/material.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// Fold, check or call, raise. Built only from what the server allows in `TURN_PROMPT.legal`:
/// no rule is decided here, a button the server did not offer simply does not exist.
class ActionButtons extends StatelessWidget {
  const ActionButtons({
    super.key,
    required this.legal,
    required this.enabled,
    required this.onFold,
    required this.onCheck,
    required this.onCall,
    required this.onRaise,
    this.buttonHeight = BrutalMetrics.tapPlayer,
    this.gap = BrutalMetrics.gapM,
    this.oneRow = false,
    this.compact = false,
  });

  final LegalActions legal;

  /// False while the link is down: nothing can be sent then.
  final bool enabled;
  final VoidCallback onFold;
  final VoidCallback onCheck;
  final VoidCallback onCall;
  final VoidCallback onRaise;

  /// Height of every button, and the space between them; a short screen asks for less.
  final double buttonHeight;
  final double gap;

  /// All three buttons in one row (fold, call or check, raise) instead of raise above the other
  /// two: half the height, for a screen that has little.
  final bool oneRow;

  /// Narrow cells: less padding, so a label stays on one line.
  final bool compact;

  /// The height the three buttons take together, so the space can be kept while they are not shown.
  static double heightFor({double buttonHeight = BrutalMetrics.tapPlayer, double gap = BrutalMetrics.gapM}) => 2 * buttonHeight + gap;

  @override
  Widget build(BuildContext context) {
    VoidCallback? guard(bool allowed, VoidCallback action) => enabled && allowed ? action : null;
    final middle = legal.canCheck
        ? BrutalButton(label: Strings.check, kind: BrutalButtonKind.info, minHeight: buttonHeight, compact: compact, onPressed: guard(true, onCheck))
        : BrutalButton(
            label: '${Strings.call} ${legal.callAmount}',
            kind: BrutalButtonKind.info,
            minHeight: buttonHeight,
            compact: compact,
            onPressed: guard(legal.canCall, onCall),
          );
    if (oneRow) {
      return Row(
        children: <Widget>[
          Expanded(
            child: BrutalButton(
              label: Strings.fold,
              kind: BrutalButtonKind.danger,
              minHeight: buttonHeight,
              compact: compact,
              onPressed: guard(legal.canFold, onFold),
            ),
          ),
          SizedBox(width: gap),
          Expanded(child: middle),
          SizedBox(width: gap),
          Expanded(
            child: BrutalButton(
              label: Strings.raise,
              kind: BrutalButtonKind.primary,
              minHeight: buttonHeight,
              compact: compact,
              onPressed: guard(legal.canRaise, onRaise),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BrutalButton(
          label: Strings.raise,
          kind: BrutalButtonKind.primary,
          heavy: true,
          minHeight: buttonHeight,
          compact: compact,
          onPressed: guard(legal.canRaise, onRaise),
        ),
        SizedBox(height: gap),
        Row(
          children: <Widget>[
            Expanded(
              child: BrutalButton(
                label: Strings.fold,
                kind: BrutalButtonKind.danger,
                minHeight: buttonHeight,
                compact: compact,
                onPressed: guard(legal.canFold, onFold),
              ),
            ),
            SizedBox(width: gap),
            Expanded(child: middle),
          ],
        ),
      ],
    );
  }
}
