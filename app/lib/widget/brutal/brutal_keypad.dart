import 'package:flutter/material.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';

/// Plain numeric grid for exact amounts. It reports key presses; the owner of the number decides
/// what is valid.
class BrutalKeypad extends StatelessWidget {
  const BrutalKeypad({super.key, required this.onDigit, required this.onBackspace, required this.onClear});

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onPressed, {BrutalButtonKind kind = BrutalButtonKind.neutral}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(BrutalMetrics.gapXs),
        child: BrutalButton(label: label, onPressed: onPressed, kind: kind, minHeight: BrutalMetrics.tapPlayer),
      ),
    );
    Widget digits(List<int> values) => Row(children: <Widget>[for (final v in values) key('$v', () => onDigit(v))]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        digits(const <int>[1, 2, 3]),
        digits(const <int>[4, 5, 6]),
        digits(const <int>[7, 8, 9]),
        Row(
          children: <Widget>[
            key('C', onClear, kind: BrutalButtonKind.danger),
            key('0', () => onDigit(0)),
            key('<', onBackspace),
          ],
        ),
      ],
    );
  }
}
