import 'package:flutter/material.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/seat_order.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';
import 'package:poker_credits/widget/brutal/brutal_pressable.dart';
import 'package:poker_credits/widget/brutal/brutal_sheet.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// The seat order as people sit in the room: ten numbered seats, clockwise. A guest taps a free
/// seat to move there; the host picks a player and then a seat (a taken seat swaps the two). It
/// only sends the request: the server decides, and only between hands.
Future<void> showSeatOrderSheet(BuildContext context, {required bool isHost}) {
  return showBrutalSheet<void>(
    context: context,
    title: Strings.seatsTitle,
    builder: (_) => SeatOrderPicker(isHost: isHost),
  );
}

class SeatOrderPicker extends StatefulWidget {
  const SeatOrderPicker({super.key, required this.isHost});

  final bool isHost;

  @override
  State<SeatOrderPicker> createState() => _SeatOrderPickerState();
}

class _SeatOrderPickerState extends State<SeatOrderPicker> with Refena {
  /// Host only: the player picked up, waiting for a target seat.
  String? _selected;

  void _tap(int target, RoomView view, String myPlayerId) {
    final result = seatTap(
      isHost: widget.isHost,
      myPlayerId: myPlayerId,
      seats: <int, SeatView>{for (final seat in view.seats) seat.seatIndex: seat},
      target: target,
      selected: _selected,
      phase: view.phase,
    );
    switch (result) {
      case SeatTapIgnored():
        break;
      case SeatTapSelect(:final playerId):
        setState(() => _selected = playerId);
      case SeatTapClear():
        setState(() => _selected = null);
      case SeatTapSend(:final message):
        setState(() => _selected = null);
        ref.notifier(sessionProvider).send(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.ref.watch(sessionProvider);
    final view = session.room.view;
    if (view == null) return const SizedBox.shrink();
    final c = BrutalTheme.of(context).colors;
    final mine = session.playerId ?? '';
    final locked = seatsLocked(view.phase);
    final seats = <int, SeatView>{for (final seat in view.seats) seat.seatIndex: seat};
    // A pick the player no longer has (kicked, left) is dropped instead of dangling.
    final selected = seats.values.any((s) => s.playerId == _selected) ? _selected : null;
    final hint = locked
        ? Strings.seatsLocked
        : selected != null
        ? Strings.seatsPicked
        : widget.isHost
        ? Strings.seatsHintHost
        : Strings.seatsHintGuest;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(hint, style: TextStyle(fontSize: 14, height: 1.4, color: c.muted)),
        const SizedBox(height: BrutalMetrics.gapM),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = BrutalMetrics.gapS;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (var i = 0; i < 10; i++)
                  SizedBox(
                    width: width,
                    child: _SeatCell(
                      index: i,
                      seat: seats[i],
                      isMine: seats[i]?.playerId == mine,
                      picked: seats[i] != null && seats[i]!.playerId == selected,
                      enabled: !locked && _enabled(seats[i], mine, selected),
                      onTap: () => _tap(i, view, mine),
                    ),
                  ),
              ],
            );
          },
        ),
        if (view.seats.length > 1) ...<Widget>[
          const SizedBox(height: BrutalMetrics.gapM),
          Text(Strings.seatsClockwise.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 1, color: c.muted)),
          const SizedBox(height: BrutalMetrics.gapXs),
          Text(
            Strings.seatsOrderLine(clockwiseNames(view.seats)),
            style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 14, height: 1.4, color: c.ink),
          ),
        ],
      ],
    );
  }

  /// A guest can only take free seats; the host can tap any seat that does something.
  bool _enabled(SeatView? seat, String mine, String? selected) {
    if (widget.isHost) return seat != null || selected != null;
    return seat == null;
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({required this.index, required this.seat, required this.isMine, required this.picked, required this.enabled, required this.onTap});

  final int index;
  final SeatView? seat;
  final bool isMine;
  final bool picked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final number = seatNumber(index);
    final name = seat == null ? Strings.seatsFree : (isMine ? '${seat!.name} (${Strings.seatsYou})' : seat!.name);
    return Semantics(
      container: true,
      button: enabled,
      selected: picked,
      label: '${Strings.seatLabel(number)}, $name',
      child: ExcludeSemantics(
        child: BrutalPressable(
          enabled: enabled,
          onTap: onTap,
          builder: (context, pressed) {
            final inverted = pressed || picked;
            final fill = inverted ? c.ink : (isMine ? c.surface : c.paper);
            final text = inverted ? c.paper : c.ink;
            return Opacity(
              opacity: enabled || seat != null ? 1 : 0.45,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  border: Border.all(color: c.line, width: isMine ? BrutalMetrics.borderHeavy : BrutalMetrics.border),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: BrutalMetrics.tapPlayer),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapS, vertical: BrutalMetrics.gapS),
                    child: Row(
                      children: <Widget>[
                        BrutalNumber(number, size: 28, color: text),
                        const SizedBox(width: BrutalMetrics.gapS),
                        Expanded(
                          child: Text(
                            seat == null ? name.toUpperCase() : name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: BrutalFonts.mono,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: seat == null && !inverted ? c.muted : text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
