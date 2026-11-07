/// Platform seam: sending the player to a web page (ADR-014).
library;

import 'package:flutter/services.dart';

/// What happened to a link.
enum LinkResult {
  /// A browser was opened.
  opened,

  /// There is no way to open a browser from here, so the link was put on the clipboard.
  copied,

  /// Neither worked.
  failed,
}

/// Opens web links. Only https links are ever passed in; an implementation may refuse anything else.
abstract interface class ExternalLinks {
  Future<LinkResult> open(Uri url);
}

/// The default: copies the link to the clipboard.
///
/// Opening a browser needs a plugin (`url_launcher`) that is not on the approved list yet
/// (docs/AGENT_CODING_GUIDE.md section 6). Adding it later means one more implementation of
/// [ExternalLinks] behind `externalLinksProvider`; no screen changes.
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
