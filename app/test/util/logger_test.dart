import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/util/logger.dart';

void main() {
  test('diagnostics buffer keeps only the most recent lines', () {
    final buffer = DiagnosticsBuffer.instance..clear();
    for (var i = 0; i < DiagnosticsBuffer.capacity + 25; i++) {
      buffer.add('line $i');
    }

    expect(buffer.lines.length, DiagnosticsBuffer.capacity);
    expect(buffer.lines.first, 'line 25');
    expect(buffer.lines.last, 'line ${DiagnosticsBuffer.capacity + 24}');
  });
}
