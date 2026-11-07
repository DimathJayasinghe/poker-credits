import 'package:flutter/material.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_credits/provider/host_provider.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/fit_page.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_segmented.dart';
import 'package:poker_credits/widget/brutal/brutal_text_field.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final RegExp _nameRule = RegExp(r'^[A-Za-z0-9 _-]{1,20}$');

/// Host setup: name and table settings, then start the embedded server and open the table.
/// The server checks every value; this form only makes sure the text is a number.
class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> with Refena {
  late final _name = TextEditingController(text: ref.read(settingsProvider).defaultName);
  final _chips = TextEditingController(text: '${defaultRoomConfig.startingChips}');
  final _small = TextEditingController(text: '${defaultRoomConfig.smallBlind}');
  final _big = TextEditingController(text: '${defaultRoomConfig.bigBlind}');
  final _seconds = TextEditingController(text: '${defaultRoomConfig.turnTimeLimitSeconds}');
  bool _submitted = false;
  CardMode _cards = defaultRoomConfig.cardMode;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[_name, _chips, _small, _big, _seconds]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _number(TextEditingController controller) => int.tryParse(controller.text.trim());

  String? _numberError(TextEditingController controller) => _submitted && _number(controller) == null ? Strings.numberInvalid : null;

  /// A message about a field goes away as soon as the field is fixed, not at the next press of Start.
  void _recheck(String _) {
    if (_submitted) setState(() {});
  }

  Future<void> _start() async {
    setState(() => _submitted = true);
    final name = _name.text.trim();
    final chips = _number(_chips);
    final small = _number(_small);
    final big = _number(_big);
    final seconds = _number(_seconds);
    if (!_nameRule.hasMatch(name) || chips == null || small == null || big == null || seconds == null) return;
    final config = RoomConfig(
      cardMode: _cards,
      startingChips: chips,
      smallBlind: small,
      bigBlind: big,
      ante: defaultRoomConfig.ante,
      isTournament: false,
      blindLevelMinutes: defaultRoomConfig.blindLevelMinutes,
      turnTimeLimitSeconds: seconds,
    );
    await ref.notifier(hostProvider).start(hostName: name, config: config);
    if (!mounted) return;
    if (ref.read(hostProvider).phase == HostPhase.ready) {
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const TablePage()));
    }
  }

  String _errorText(HostException error) {
    final text = switch (error.failure) {
      HostFailure.portBusy => Strings.hostFailedPort,
      HostFailure.storage => Strings.hostFailedStorage,
      HostFailure.crashed => Strings.hostFailedCrashed,
      HostFailure.refused => '${Strings.hostFailedRefused} ${error.message}',
      HostFailure.unavailable => Strings.hostingUnavailable,
      HostFailure.unknown => Strings.hostFailedUnknown,
    };
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final host = context.ref.watch(hostProvider);
    final busy = host.phase == HostPhase.starting;
    return FitPage(
      title: Strings.hostTitle,
      onBack: busy ? null : () => Navigator.of(context).maybePop(),
      compactBelow: 800,
      tightBelow: 560,
      footer: (context, info) => BrutalButton(
        label: busy ? Strings.starting : Strings.startHosting,
        kind: BrutalButtonKind.primary,
        heavy: true,
        minHeight: info.roomy ? BrutalMetrics.tapPlayer : 52,
        onPressed: busy ? null : _start,
      ),
      builder: (context, info) {
        Widget gap() => SizedBox(height: info.gap);
        Widget number(String label, TextEditingController controller) => BrutalTextField(
          label: label,
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: _recheck,
          errorText: _numberError(controller),
        );
        Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: a),
            SizedBox(width: info.gap),
            Expanded(child: b),
          ],
        );
        final name = BrutalTextField(
          label: Strings.hostName,
          controller: _name,
          maxLength: 20,
          onChanged: _recheck,
          errorText: _submitted && !_nameRule.hasMatch(_name.text.trim()) ? Strings.nameInvalid : null,
        );
        final timerHint = Text(Strings.turnSecondsHint, style: TextStyle(fontSize: 13, height: 1.3, color: c.muted));
        final seconds = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            number(Strings.turnSeconds, _seconds),
            const SizedBox(height: BrutalMetrics.gapXs),
            timerHint,
          ],
        );
        final cards = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!info.tight) ...<Widget>[
              Text(
                Strings.cardsLabel,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c.ink),
              ),
              const SizedBox(height: BrutalMetrics.gapS),
            ],
            BrutalSegmented<CardMode>(
              semanticLabel: Strings.cardsLabel,
              value: _cards,
              options: const <(CardMode, String)>[(CardMode.physical, Strings.cardsReal), (CardMode.virtual, Strings.cardsVirtual)],
              onChanged: busy ? (_) {} : (v) => setState(() => _cards = v),
            ),
            if (_cards == CardMode.virtual) ...<Widget>[
              const SizedBox(height: BrutalMetrics.gapS),
              const BrutalBanner(message: Strings.hostTrustNote, kind: BrutalBannerKind.info),
            ],
          ],
        );
        final error = host.error == null
            ? null
            : Padding(
                padding: EdgeInsets.only(bottom: info.gap),
                child: BrutalBanner(message: _errorText(host.error!), kind: BrutalBannerKind.error),
              );
        if (info.sideBySide) {
          // On its side: who you are, the timer and the cards on the left, the stakes on the right.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ?error,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        name,
                        gap(),
                        seconds,
                        gap(),
                        cards,
                      ],
                    ),
                  ),
                  SizedBox(width: info.pad),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        number(Strings.startingChips, _chips),
                        gap(),
                        number(Strings.smallBlind, _small),
                        gap(),
                        number(Strings.bigBlind, _big),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        final settings = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            pair(number(Strings.startingChips, _chips), seconds),
            gap(),
            pair(number(Strings.smallBlind, _small), number(Strings.bigBlind, _big)),
            gap(),
            cards,
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ?error,
            FitSection(info: info, label: info.roomy ? Strings.you : null, child: name),
            gap(),
            FitSection(info: info, label: info.roomy ? Strings.gameSettings : null, child: settings),
          ],
        );
      },
    );
  }
}
