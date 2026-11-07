/// Certificate pinning for LAN games (ADR-019).
///
/// A host phone cannot get a certificate from a public authority, so it makes its own and the
/// guest recognises it by its fingerprint: SHA-256 of the certificate, 43 URL-safe base64
/// characters. The fingerprint travels with the address in a URI fragment
/// (`wss://192.168.1.5:7878/v1/ws#pin=…`), which is never sent over the network, so the address
/// and what it must prove fit in one string that the session store keeps as it is.
library;

final RegExp _pinShape = RegExp(r'^[A-Za-z0-9_-]{43}$');

const String _pinKey = 'pin';

/// Whether [text] has the shape of a fingerprint. It does not say the fingerprint is right.
bool isPin(String? text) => text != null && _pinShape.hasMatch(text);

/// [uri] with [pin] attached; [uri] unchanged when [pin] is null.
Uri withPin(Uri uri, String? pin) {
  if (pin == null) return uri;
  if (!isPin(pin)) throw ArgumentError.value(pin, 'pin', 'not a fingerprint');
  return uri.replace(fragment: '$_pinKey=$pin');
}

/// The fingerprint [uri] must show, or `null` when it carries none (or a malformed one).
String? pinOf(Uri uri) {
  final fragment = uri.fragment;
  if (!fragment.startsWith('$_pinKey=')) return null;
  final pin = fragment.substring(_pinKey.length + 1);
  return isPin(pin) ? pin : null;
}

/// [uri] without the fragment, which is what actually gets connected to.
Uri withoutPin(Uri uri) => uri.hasFragment ? uri.removeFragment() : uri;

/// Whether [host] is this device (the only place a plaintext socket is allowed).
bool isLoopbackHost(String host) => host == '127.0.0.1' || host == 'localhost' || host == '::1' || host == '[::1]';

/// The host showed a certificate other than the one the guest was told to expect. Nothing was
/// sent to it. The game must not carry on with this host.
class PinMismatch implements Exception {
  const PinMismatch();

  @override
  String toString() => 'PinMismatch';
}

/// The host does not speak the encrypted protocol: an older version of the app, or something
/// that is not a Poker Credits host at all.
class NoSecureChannel implements Exception {
  const NoSecureChannel();

  @override
  String toString() => 'NoSecureChannel';
}

/// A plaintext socket to another device was asked for. It is never opened.
class InsecureAddress implements Exception {
  const InsecureAddress(this.uri);

  final Uri uri;

  @override
  String toString() => 'InsecureAddress($uri)';
}
