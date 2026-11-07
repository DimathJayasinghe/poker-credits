import 'package:flutter/material.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_slider.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// The body of the raise sheet: a slider between the server's minimum and maximum raise.
/// Reaching the maximum turns the confirm button into an all-in.
class RaiseSlider extends StatefulWidget {
  const RaiseSlider({super.key, required this.legal, required this.onConfirm});

  final LegalActions legal;

  /// Called with the chosen action: [RaiseAction], or [AllInAction] at the maximum.
  final ValueChanged<PlayerAction> onConfirm;

  @override
  State<RaiseSlider> createState() => _RaiseSliderState();
}

class _RaiseSliderState extends State<RaiseSlider> {
  late int _value = widget.legal.minRaiseTo;

  int get _min => widget.legal.minRaiseTo;
  int get _max => widget.legal.maxRaiseTo < _min ? _min : widget.legal.maxRaiseTo;
  bool get _allIn => _value >= _max;

  @override
  Widget build(BuildContext context) {
    final step = _step(_max - _min);
    // On a phone held on its side the sheet has little height: a tighter slider and button.
    final short = MediaQuery.sizeOf(context).height < 460;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BrutalSlider(
          value: _value,
          min: _min,
          max: _max,
          step: step,
          semanticLabel: Strings.raiseTo,
          stepButtons: true,
          compact: short,
          ticks: <BrutalTick>[BrutalTick(Strings.min, _min), BrutalTick(Strings.max, _max)],
          onChanged: (v) => setState(() => _value = v),
        ),
        SizedBox(height: short ? BrutalMetrics.gapS : BrutalMetrics.gapL),
        BrutalButton(
          label: _allIn ? '${Strings.allInAction} $_max' : '${Strings.raiseTo} $_value',
          kind: BrutalButtonKind.primary,
          heavy: true,
          minHeight: short ? 48 : BrutalMetrics.tapPlayer,
          onPressed: () => widget.onConfirm(_allIn ? const AllInAction() : RaiseAction(toAmount: _value)),
        ),
      ],
    );
  }

  /// Finer steps for a small range, coarser for a big one, so a thumb can land on a value.
  /// The ends of the range are always reachable.
  static int _step(int range) {
    if (range <= 100) return 1;
    if (range <= 1000) return 5;
    return 10;
  }
}
