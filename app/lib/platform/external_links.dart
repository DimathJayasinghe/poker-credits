/// Platform seam: sending the player to a web page (ADR-014).
library;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// What happened to a link.
enum LinkResult {
  /// The link was opened in the browser.
  opened,

  /// The browser could not be opened, so the link was put on the clipboard.
  copied,

  /// Neither worked.
  failed,
}

/// Opens web links. Only https links are ever passed in; an implementation may refuse anything else.
abstract interface class ExternalLinks {
  Future<LinkResult> open(Uri url);
}

/// The default: opens the link in the system browser, outside the app. Where that is not possible
/// (no browser, a restricted device, the launcher refusing) the link is copied instead, so the
/// player can still paste it somewhere.
///
/// Only `https` links are launched. The launcher and the clipboard are injectable for tests.
class BrowserExternalLinks implements ExternalLinks {
  const BrowserExternalLinks({this.launch = _launch, this.fallback = const ClipboardExternalLinks()});

  final Future<bool> Function(Uri url) launch;
  final ExternalLinks fallback;

  static Future<bool> _launch(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Future<LinkResult> open(Uri url) async {
    if (url.scheme != 'https') return LinkResult.failed;
    try {
      if (await launch(url)) return LinkResult.opened;
    } on Object {
      // Falls through to the clipboard.
    }
    return fallback.open(url);
  }
}

/// Copies the link to the clipboard. The fallback of [BrowserExternalLinks].
class ClipboardExternalLinks implements ExternalLinks {
  const ClipboardExternalLinks();

  @override
  Future<LinkResult> open(Uri url) async {
    if (url.scheme != 'https') return LinkResult.failed;
    try {
      await Clipboard.setData(ClipboardData(text: url.toString()));
      return LinkResult.copied;
    } on Object {
      return LinkResult.failed;
    }
  }
}
