import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/model/join_link.dart';
import 'package:poker_credits/platform/host_server_io.dart';
import 'package:poker_credits/widget/table/table_fit.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../support/fakes.dart';

/// The join code carries a 43-character fingerprint (ADR-019), so it is a bigger QR than before.
/// A camera needs a few device pixels per square, and the smallest code sits on a phone held on
/// its side. This turns "is it still scannable" into numbers that fail if the link or the sizes
/// change for the worse.
void main() {
  // The longest realistic text: a private address with three-digit parts and the fallback port.
  const longest = JoinLink(hostAndPort: '192.168.100.100:${defaultHostPort + 1}', roomCode: 'KQ7M', fingerprint: testPin);
  const typical = JoinLink(hostAndPort: '192.168.1.5:$defaultHostPort', roomCode: 'KQ7M', fingerprint: testPin);

  int modules(JoinLink link) => QrCode.fromData(data: link.toString(), errorCorrectLevel: QrErrorCorrectLevel.L).moduleCount;

  test('the join link stays within QR version 5 (37 squares a side) at the lowest repair level', () {
    expect(modules(typical), lessThanOrEqualTo(37));
    expect(modules(longest), lessThanOrEqualTo(37));
    expect(longest.toString().length, lessThanOrEqualTo(106), reason: 'version 5, level L holds 106 bytes');
  });

  test('every size the host screen draws the code at gives each square at least 2.5 logical pixels', () {
    const floor = 2.5;
    final sizes = <String, double>{'phone on its side': 96, for (final tier in _tiers) tier.$1: tier.$2};
    for (final entry in sizes.entries) {
      final perSquare = entry.value / modules(longest);
      expect(perSquare, greaterThanOrEqualTo(floor), reason: '${entry.key}: ${entry.value} px over ${modules(longest)} squares is $perSquare px');
    }
  });
}

/// The code sizes of the table tiers.
List<(String, double)> get _tiers => <(String, double)>[
  ('roomy table', TableFit.roomy.qr),
  ('snug table', TableFit.snug.qr),
  ('tight table', TableFit.tight.qr),
];
