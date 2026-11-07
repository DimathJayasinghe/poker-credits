import 'package:flutter/material.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/table_page.dart';
import 'package:poker_credits/provider/host_provider.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/app_shell.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/paper_backdrop.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
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
    final host = context.ref.watch(hostProvider);
    final busy = host.phase == HostPhase.starting;
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTopBar(title: Strings.hostTitle, onBack: busy ? null : () => Navigator.of(context).maybePop()),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BrutalMetrics.gapM),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (host.error != null) ...<Widget>[
                        BrutalBanner(message: _errorText(host.error!), kind: BrutalBannerKind.error),
                        const SizedBox(height: BrutalMetrics.gapM),
                      ],
                      BrutalCard(
                        header: Strings.you,
                        child: BrutalTextField(
                          label: Strings.hostName,
                          controller: _name,
                          autofocus: true,
                          maxLength: 20,
                          errorText: _submitted && !_nameRule.hasMatch(_name.text.trim()) ? Strings.nameInvalid : null,
                        ),
                      ),
                      const SizedBox(height: BrutalMetrics.gapM),
                      BrutalCard(
                        header: Strings.gameSettings,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            BrutalTextField(
                              label: Strings.startingChips,
                              controller: _chips,
                              keyboardType: TextInputType.number,
                              errorText: _numberError(_chips),
                            ),
                            const SizedBox(height: BrutalMetrics.gapM),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: BrutalTextField(
                                    label: Strings.smallBlind,
                                    controller: _small,
                                    keyboardType: TextInputType.number,
                                    errorText: _numberError(_small),
                                  ),
                                ),
                                const SizedBox(width: BrutalMetrics.gapM),
                                Expanded(
                                  child: BrutalTextField(
                                    label: Strings.bigBlind,
                                    controller: _big,
                                    keyboardType: TextInputType.number,
                                    errorText: _numberError(_big),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: BrutalMetrics.gapM),
                            BrutalTextField(
                              label: Strings.turnSeconds,
                              controller: _seconds,
                              keyboardType: TextInputType.number,
                              errorText: _numberError(_seconds),
                            ),
                            const SizedBox(height: BrutalMetrics.gapM),
                            Text(
                              Strings.cardsLabel,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BrutalTheme.of(context).colors.ink),
                            ),
                            const SizedBox(height: BrutalMetrics.gapS),
                            BrutalSegmented<CardMode>(
                              semanticLabel: Strings.cardsLabel,
                              value: _cards,
                              options: const <(CardMode, String)>[
                                (CardMode.physical, Strings.cardsReal),
                                (CardMode.virtual, Strings.cardsVirtual),
                              ],
                              onChanged: busy ? (_) {} : (v) => setState(() => _cards = v),
                            ),
                            if (_cards == CardMode.virtual) ...<Widget>[
                              const SizedBox(height: BrutalMetrics.gapS),
                              const BrutalBanner(message: Strings.hostTrustNote, kind: BrutalBannerKind.info),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: BrutalMetrics.gapL),
                      BrutalButton(
                        label: busy ? Strings.starting : Strings.startHosting,
                        kind: BrutalButtonKind.primary,
                        heavy: true,
                        minHeight: BrutalMetrics.tapPlayer,
                        onPressed: busy ? null : _start,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
