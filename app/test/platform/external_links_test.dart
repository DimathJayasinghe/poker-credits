import 'package:flutter_test/flutter_test.dart';
import 'package:poker_credits/platform/external_links.dart';

class _Copies implements ExternalLinks {
  final List<Uri> seen = <Uri>[];

  @override
  Future<LinkResult> open(Uri url) async {
    seen.add(url);
    return LinkResult.copied;
  }
}

void main() {
  final github = Uri.parse('https://github.com/DimathJayasinghe/poker-credits');

  test('an https link is opened in the browser', () async {
    final launched = <Uri>[];
    final copies = _Copies();
    final links = BrowserExternalLinks(
      launch: (url) async {
        launched.add(url);
        return true;
      },
      fallback: copies,
    );
    expect(await links.open(github), LinkResult.opened);
    expect(launched, <Uri>[github]);
    expect(copies.seen, isEmpty);
  });

  test('when the browser cannot be launched the link is copied instead', () async {
    final copies = _Copies();
    expect(await BrowserExternalLinks(launch: (_) async => false, fallback: copies).open(github), LinkResult.copied);
    expect(copies.seen, <Uri>[github]);
  });

  test('a launcher that throws also falls back to copying', () async {
    final copies = _Copies();
    final links = BrowserExternalLinks(launch: (_) async => throw StateError('no handler'), fallback: copies);
    expect(await links.open(github), LinkResult.copied);
  });

  test('anything that is not https is refused and never launched', () async {
    var launched = false;
    final links = BrowserExternalLinks(
      launch: (_) async {
        launched = true;
        return true;
      },
      fallback: _Copies(),
    );
    for (final raw in <String>['http://example.com', 'file:///etc/passwd', 'javascript:alert(1)', 'intent://x#Intent;end', 'mailto:a@b.c']) {
      expect(await links.open(Uri.parse(raw)), LinkResult.failed, reason: raw);
    }
    expect(launched, isFalse);
  });
}
