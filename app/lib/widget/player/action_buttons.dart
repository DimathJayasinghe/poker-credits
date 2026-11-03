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
  });

  final LegalActions legal;

  /// False while the link is down: nothing can be sent then.
  final bool enabled;
  final VoidCallback onFold;
  final VoidCallback onCheck;
  final VoidCallback onCall;
  final VoidCallback onRaise;

  @override
  Widget build(BuildContext context) {
    VoidCallback? guard(bool allowed, VoidCallback action) => enabled && allowed ? action : null;
    final middle = legal.canCheck
        ? BrutalButton(label: Strings.check, kind: BrutalButtonKind.info, minHeight: BrutalMetrics.tapPlayer, onPressed: guard(true, onCheck))
        : BrutalButton(
            label: '${Strings.call} ${legal.callAmount}',
            kind: BrutalButtonKind.info,
            minHeight: BrutalMetrics.tapPlayer,
            onPressed: guard(legal.canCall, onCall),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BrutalButton(
          label: Strings.raise,
          kind: BrutalButtonKind.primary,
          heavy: true,
          minHeight: BrutalMetrics.tapPlayer,
          onPressed: guard(legal.canRaise, onRaise),
        ),
        const SizedBox(height: BrutalMetrics.gapM),
        Row(
          children: <Widget>[
            Expanded(
              child: BrutalButton(
                label: Strings.fold,
                kind: BrutalButtonKind.danger,
                minHeight: BrutalMetrics.tapPlayer,
                onPressed: guard(legal.canFold, onFold),
              ),
            ),
            const SizedBox(width: BrutalMetrics.gapM),
            Expanded(child: middle),
          ],
        ),
      ],
    );
  }
}
