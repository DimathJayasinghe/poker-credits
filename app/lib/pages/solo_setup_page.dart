import 'package:flutter/material.dart';
import 'package:poker_credits/model/hosting.dart';
import 'package:poker_credits/pages/solo_table_page.dart';
import 'package:poker_credits/provider/settings_provider.dart';
import 'package:poker_credits/provider/solo_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_segmented.dart';
import 'package:poker_credits/widget/brutal/brutal_slider.dart';
import 'package:poker_credits/widget/brutal/brutal_text_field.dart';
import 'package:poker_credits/widget/brutal/fit_page.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final RegExp _nameRule = RegExp(r'^[A-Za-z0-9 _-]{1,20}$');

String _skillCaption(BotSkill skill) => switch (skill) {
  BotSkill.easy => Strings.skillEasyCaption,
  BotSkill.normal => Strings.skillNormalCaption,
  BotSkill.hard => Strings.skillHardCaption,
};

String _lengthCaption(SoloLength length) => switch (length) {
  SoloLength.quick => Strings.lengthQuickCaption,
  SoloLength.standard => Strings.lengthStandardCaption,
  SoloLength.long => Strings.lengthLongCaption,
};

/// Setup of a single-player game: how many computer players, how well they play and how fast the
/// blinds rise. The server checks every value; this form only offers sensible ones. The last
/// choices are remembered on this device.
class SoloSetupPage extends StatefulWidget {
  const SoloSetupPage({super.key});

  @override
  State<SoloSetupPage> createState() => _SoloSetupPageState();
}

class _SoloSetupPageState extends State<SoloSetupPage> with Refena {
  late final _name = TextEditingController(text: ref.read(settingsProvider).defaultName);
  late int _bots = ref.read(settingsProvider).soloBots;
  late BotSkill _skill = ref.read(settingsProvider).soloSkill;
  late SoloLength _length = ref.read(settingsProvider).soloLength;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// A message about a field goes away as soon as the field is fixed, not at the next press of Start.
  void _recheck(String _) {
    if (_submitted) setState(() {});
  }

  Future<void> _start() async {
    setState(() => _submitted = true);
    final name = _name.text.trim();
    if (!_nameRule.hasMatch(name)) return;
    ref.notifier(settingsProvider).update((s) => s.copyWith(soloBots: _bots, soloSkill: _skill, soloLength: _length));
    final ok = await ref
        .notifier(soloProvider)
        .start(
          name: name,
          solo: SoloConfig(bots: _bots, skill: _skill, ladderHands: _length.ladderHands),
        );
    if (!mounted || !ok) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const SoloTablePage()));
  }

  String _errorText(HostException error) => switch (error.failure) {
    HostFailure.storage => Strings.soloFailedStorage,
    HostFailure.unavailable => Strings.soloFailedUnavailable,
    _ => Strings.soloFailedUnknown,
  };

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final solo = context.ref.watch(soloProvider);
    final settings = context.ref.watch(settingsProvider);
    final busy = solo.phase == SoloPhase.starting;
    final record = settings.recordFor(_bots, _skill);
    return FitPage(
      title: Strings.soloTitle,
      onBack: busy ? null : () => Navigator.of(context).maybePop(),
      compactBelow: 860,
      tightBelow: 560,
      footer: (context, info) => BrutalButton(
        label: busy ? Strings.soloStarting : Strings.startSolo,
        kind: BrutalButtonKind.primary,
        heavy: true,
        minHeight: info.roomy ? BrutalMetrics.tapPlayer : 52,
        onPressed: busy ? null : _start,
      ),
      builder: (context, info) {
        final name = FitSection(
          info: info,
          child: BrutalTextField(
            label: Strings.hostName,
            controller: _name,
            maxLength: 20,
            onChanged: _recheck,
            errorText: _submitted && !_nameRule.hasMatch(_name.text.trim()) ? Strings.nameInvalid : null,
          ),
        );
        final opponents = FitSection(
          info: info,
          label: Strings.soloOpponents,
          child: BrutalSlider(
            value: _bots,
            min: minSoloBots,
            max: maxSoloBots,
            stepButtons: true,
            compact: !info.roomy,
            semanticLabel: Strings.soloOpponents,
            onChanged: busy ? (_) {} : (v) => setState(() => _bots = v),
          ),
        );
        final skill = FitSection(
          info: info,
          label: Strings.soloSkill,
          hint: _skillCaption(_skill),
          child: BrutalSegmented<BotSkill>(
            semanticLabel: Strings.soloSkill,
            value: _skill,
            options: const <(BotSkill, String)>[
              (BotSkill.easy, Strings.skillEasy),
              (BotSkill.normal, Strings.skillNormal),
              (BotSkill.hard, Strings.skillHard),
            ],
            onChanged: busy ? (_) {} : (v) => setState(() => _skill = v),
          ),
        );
        final length = FitSection(
          info: info,
          label: Strings.soloLength,
          hint: _lengthCaption(_length),
          child: BrutalSegmented<SoloLength>(
            semanticLabel: Strings.soloLength,
            value: _length,
            options: const <(SoloLength, String)>[
              (SoloLength.quick, Strings.lengthQuick),
              (SoloLength.standard, Strings.lengthStandard),
              (SoloLength.long, Strings.lengthLong),
            ],
            onChanged: busy ? (_) {} : (v) => setState(() => _length = v),
          ),
        );
        final notes = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(info.tight ? Strings.soloRulesShort : Strings.soloRules, style: TextStyle(fontSize: 13, height: 1.3, color: c.muted)),
            // With no finished game yet there is nothing to report; a short page keeps its height.
            if (record != null || !info.tight) ...<Widget>[
              SizedBox(height: info.tight ? BrutalMetrics.gapXs : BrutalMetrics.gapS),
              Text(
                record == null ? Strings.soloRecordNone : Strings.soloRecordLine(record.bestPlace, record.wins, record.played),
                key: const ValueKey<String>('solo-record'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.ink),
              ),
            ],
          ],
        );
        final error = solo.error == null
            ? null
            : Padding(
                padding: EdgeInsets.only(bottom: info.gap),
                child: BrutalBanner(message: _errorText(solo.error!), kind: BrutalBannerKind.error),
              );
        Widget gap() => SizedBox(height: info.gap);
        if (info.sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ?error,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[name, gap(), opponents, gap(), notes]),
                  ),
                  SizedBox(width: info.pad),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[skill, gap(), length]),
                  ),
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[?error, name, gap(), opponents, gap(), skill, gap(), length, gap(), notes],
        );
      },
    );
  }
}
