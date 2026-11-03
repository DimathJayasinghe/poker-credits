import 'package:flutter/material.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/pages/player_page.dart';
import 'package:poker_credits/pages/scan_page.dart';
import 'package:poker_credits/pages/spectator_page.dart';
import 'package:poker_credits/platform/qr_scanner.dart';
import 'package:poker_credits/provider/connection_provider.dart';
import 'package:poker_credits/provider/join_provider.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/describe.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_banner.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_card.dart';
import 'package:poker_credits/widget/brutal/brutal_text_field.dart';
import 'package:poker_protocol/poker_protocol.dart';
import 'package:refena_flutter/refena_flutter.dart';

final RegExp _nameRule = RegExp(r'^[A-Za-z0-9 _-]{1,20}$');

/// Join a game: scan the host's QR code or type the room code and address, pick a name.
/// A rejected join (bad name, full table) stays on this page so it can be fixed and retried.
class JoinPage extends StatefulWidget {
  const JoinPage({super.key, this.initial});

  /// Pre-filled from a scanned code or a link.
  final JoinLink? initial;

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> with Refena {
  late final TextEditingController _code = TextEditingController(text: widget.initial?.roomCode ?? '');
  late final TextEditingController _address = TextEditingController(text: widget.initial?.hostAndPort ?? '');
  final TextEditingController _name = TextEditingController();
  bool _submitted = false;
  bool _attempting = false;
  bool _spectator = false;
  bool _handedOff = false;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[_code, _address, _name]) {
      controller.dispose();
    }
    // Leaving the page while still trying to connect cancels the attempt. When it worked the
    // session lives on in the player or spectator page.
    if (_attempting && !_handedOff) ref.read(joinProvider).leave();
    super.dispose();
  }

  Future<void> _scan() async {
    final link = await Navigator.of(context).push<JoinLink>(MaterialPageRoute<JoinLink>(builder: (_) => const ScanPage()));
    if (link == null || !mounted) return;
    setState(() {
      _code.text = link.roomCode;
      _address.text = link.hostAndPort;
    });
  }

  void _join({required bool spectator}) {
    setState(() => _submitted = true);
    final code = JoinLink.normalizeRoomCode(_code.text);
    final address = JoinLink.normalizeAddress(_address.text);
    if (code == null || address == null || !_nameRule.hasMatch(_name.text.trim())) return;
    setState(() {
      _attempting = true;
      _spectator = spectator;
    });
    ref
        .read(joinProvider)
        .join(
          link: JoinLink(hostAndPort: address, roomCode: code),
          name: _name.text,
          spectator: spectator,
        );
  }

  Future<void> _cancel() async {
    await ref.read(joinProvider).leave();
    if (mounted) setState(() => _attempting = false);
  }

  /// Opens the player or spectator page once the server has sent the first snapshot.
  void _handOffWhenReady(SessionState session) {
    if (!_attempting || _handedOff) return;
    if (!session.link.isLive || session.room.view == null) return;
    _handedOff = true;
    final watch = _spectator || session.role == Role.spectator;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => watch ? const SpectatorPage() : const PlayerPage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.ref.watch(sessionProvider);
    final c = BrutalTheme.of(context).colors;
    _handOffWhenReady(session);

    String? problem;
    var connecting = false;
    if (_attempting) {
      final error = session.room.lastError;
      final failure = session.link.failure;
      if (error != null) {
        problem = errorText(error.code);
      } else if (failure != null) {
        problem = linkFailureText(failure);
      } else if (!session.link.isLive) {
        connecting = true;
        if (session.link.attempt >= 2) problem = Strings.cannotReach;
      }
    }
    final busy = _attempting && problem == null || connecting;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BrutalMetrics.gapM),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    Strings.joinTitle.toUpperCase(),
                    style: TextStyle(fontFamily: BrutalFonts.display, fontSize: 40, height: 1, color: c.ink),
                  ),
                  const SizedBox(height: BrutalMetrics.gapL),
                  if (problem != null) ...<Widget>[
                    BrutalBanner(message: problem, kind: connecting ? BrutalBannerKind.warning : BrutalBannerKind.error),
                    const SizedBox(height: BrutalMetrics.gapM),
                  ] else if (connecting) ...<Widget>[
                    const BrutalBanner(message: Strings.connecting),
                    const SizedBox(height: BrutalMetrics.gapM),
                  ],
                  if (qrScanSupported) ...<Widget>[
                    BrutalButton(
                      label: Strings.scanQr,
                      kind: BrutalButtonKind.info,
                      minHeight: BrutalMetrics.tapPlayer,
                      onPressed: busy ? null : _scan,
                    ),
                    const SizedBox(height: BrutalMetrics.gapM),
                  ],
                  BrutalCard(
                    header: Strings.joinGame,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        BrutalTextField(
                          label: Strings.joinCode,
                          controller: _code,
                          maxLength: 4,
                          textCapitalization: TextCapitalization.characters,
                          errorText: _submitted && JoinLink.normalizeRoomCode(_code.text) == null ? Strings.codeInvalid : null,
                        ),
                        const SizedBox(height: BrutalMetrics.gapM),
                        BrutalTextField(
                          label: Strings.joinAddress,
                          controller: _address,
                          keyboardType: TextInputType.url,
                          errorText: _submitted && JoinLink.normalizeAddress(_address.text) == null ? Strings.addressInvalid : null,
                        ),
                        const SizedBox(height: BrutalMetrics.gapM),
                        BrutalTextField(
                          label: Strings.joinName,
                          controller: _name,
                          maxLength: 20,
                          errorText: _submitted && !_nameRule.hasMatch(_name.text.trim()) ? Strings.nameInvalid : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: BrutalMetrics.gapL),
                  BrutalButton(
                    label: Strings.joinButton,
                    kind: BrutalButtonKind.primary,
                    heavy: true,
                    minHeight: BrutalMetrics.tapPlayer,
                    onPressed: busy ? null : () => _join(spectator: false),
                  ),
                  const SizedBox(height: BrutalMetrics.gapM),
                  BrutalButton(label: Strings.watchButton, minHeight: BrutalMetrics.tapPlayer, onPressed: busy ? null : () => _join(spectator: true)),
                  if (busy) ...<Widget>[
                    const SizedBox(height: BrutalMetrics.gapM),
                    BrutalButton(label: Strings.cancel, kind: BrutalButtonKind.danger, onPressed: _cancel),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
