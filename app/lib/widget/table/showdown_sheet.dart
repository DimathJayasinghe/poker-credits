import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_protocol/poker_protocol.dart';

/// Host picks the winner(s) of every pot. Who may win a pot comes from the server
/// (`PotView.eligiblePlayerIds`); the app never works that out itself. More than one winner of
/// the same pot means a split; the server divides the chips.
class ShowdownSheet extends StatefulWidget {
  const ShowdownSheet({super.key, required this.pots, required this.seats, required this.onConfirm});

  final List<PotView> pots;
  final List<SeatView> seats;
  final ValueChanged<List<WireAllocation>> onConfirm;

  @override
  State<ShowdownSheet> createState() => _ShowdownSheetState();
}

class _ShowdownSheetState extends State<ShowdownSheet> {
  final Map<int, Set<String>> _winners = <int, Set<String>>{};

  String _name(String playerId) {
    for (final seat in widget.seats) {
      if (seat.playerId == playerId) return seat.name;
    }
    return playerId;
  }

  bool get _complete => widget.pots.every((pot) => (_winners[pot.tierIndex] ?? const <String>{}).isNotEmpty);

  void _toggle(int tier, String playerId) {
    setState(() {
      final set = _winners.putIfAbsent(tier, () => <String>{});
      if (!set.add(playerId)) set.remove(playerId);
    });
  }

  Widget _pot(BuildContext context, PotView pot, {required bool short}) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${Strings.potLabel.toUpperCase()} ${pot.tierIndex + 1}: ${pot.amount}',
          style: TextStyle(fontFamily: BrutalFonts.display, fontSize: short ? 20 : 24, color: c.ink),
        ),
        SizedBox(height: short ? BrutalMetrics.gapXs : BrutalMetrics.gapS),
        if (pot.eligiblePlayerIds.isEmpty)
          Text(
            Strings.noEligible.toUpperCase(),
            style: TextStyle(color: c.ink, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
          )
        else
          Wrap(
            spacing: BrutalMetrics.gapS,
            runSpacing: BrutalMetrics.gapS,
            children: <Widget>[
              for (final id in pot.eligiblePlayerIds)
                _WinnerChip(
                  short: short,
                  label: _name(id),
                  selected: (_winners[pot.tierIndex] ?? const <String>{}).contains(id),
                  onTap: () => _toggle(pot.tierIndex, id),
                ),
            ],
          ),
      ],
    );
  }

  /// The list of pots scrolls when there are more players and pots than the screen has room for;
  /// the confirm button under it never does.
  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  Strings.chooseWinners.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: c.muted),
                ),
                const SizedBox(height: BrutalMetrics.gapS),
                // Two pots side by side where the sheet is wide (a phone on its side).
                LayoutBuilder(
                  builder: (context, box) {
                    final short = MediaQuery.sizeOf(context).height < 460;
                    const gap = BrutalMetrics.gapM;
                    final columns = box.maxWidth >= 640 && widget.pots.length > 1 ? 2 : 1;
                    final width = (box.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: <Widget>[
                        for (final pot in widget.pots)
                          SizedBox(
                            width: width,
                            child: _pot(context, pot, short: short),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: BrutalMetrics.gapS),
        BrutalButton(
          label: Strings.confirmWinners,
          kind: BrutalButtonKind.primary,
          heavy: true,
          minHeight: MediaQuery.sizeOf(context).height < 460 ? 48 : BrutalMetrics.tapPlayer,
          onPressed: _complete
              ? () => widget.onConfirm(<WireAllocation>[
                  for (final pot in widget.pots)
                    WireAllocation(
                      potIndex: pot.tierIndex,
                      winnerPlayerIds: pot.eligiblePlayerIds.where((id) => (_winners[pot.tierIndex] ?? const <String>{}).contains(id)).toList(),
                    ),
                ])
              : null,
        ),
      ],
    );
  }
}

class _WinnerChip extends StatelessWidget {
  const _WinnerChip({required this.short, required this.label, required this.selected, required this.onTap});

  /// A short screen: a slightly lower chip.
  final bool short;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BrutalPressable(
        onTap: onTap,
        builder: (context, pressed) {
          final duration = BrutalTheme.duration(context, BrutalMetrics.fast);
          final Color fill = pressed ? c.ink : (selected ? c.accent : c.surface);
          final Color text = pressed ? c.paper : (selected ? c.onAccent : c.ink);
          return AnimatedContainer(
            duration: duration,
            constraints: BoxConstraints(minHeight: short ? 44 : BrutalMetrics.tap, minWidth: BrutalMetrics.tap),
            padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: c.line, width: BrutalMetrics.border),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AnimatedDefaultTextStyle(
                duration: duration,
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 16, color: text),
                child: Text('${selected ? '[x] ' : '[ ] '}${label.toUpperCase()}'),
              ),
            ),
          );
        },
      ),
    );
  }
}
