// Relay endpoint resolution.
//
// The app always connects to a SINGLE relay at a time, regardless of
// how many peers it's paired with. The URL is resolved from:
//
//   1. `prefs.relayUrl` (user override, set via Settings or onboarding)
//   2. `kDefaultRelayUrl` (the public community relay)
//
// Canonical scheme on storage is `http://` or `https://` — this is
// the form the user types and what we keep in Preferences. The WebSocket
// transport calls [toWsRelayUrl] right before opening the socket; the
// mesh HTTP client uses the URL as-is. The legacy `ws://` / `wss://`
// schemes are NOT accepted on input — the app is pre-release and
// historical persisted values get re-set by the user during the
// onboarding gate.
//
// `peer.relayUrl` is kept on PeerRecord for legacy QR code payloads but
// is no longer consulted when opening a connection — the resolution is
// global, not per-peer.

import 'package:app/data/preferences/preferences.dart';

/// Public community relay. Hardcoded; not configurable at build time
/// to keep the onboarding flow deterministic.
const String kDefaultRelayUrl = 'https://relay-rp1.jacobmoura.work';

/// User-facing message returned when [isValidRelayUrl] rejects a value.
/// Surfaced verbatim by Settings and Onboarding — keep stable for
/// localization later. Empty input gets a more generic message; the
/// ws/wss case is called out explicitly so the user understands the
/// app does the conversion internally.
const String kRelayUrlInvalidScheme =
    'Use http:// or https:// (not ws:// or wss:// — the app converts '
    'to WebSocket automatically).';

const String kRelayUrlInvalidGeneric =
    'Enter a valid URL starting with https:// (or http:// for local '
    'relays).';

/// Returns the effective relay URL the app should connect to.
/// Falls back to [kDefaultRelayUrl] when no user override is set.
/// Always returns an `http(s)://` URL — caller is responsible for
/// applying [toWsRelayUrl] when opening a WebSocket.
String resolveRelayUrl(Preferences prefs) =>
    prefs.relayUrl != null ? normalizeRelayUrl(prefs.relayUrl!) : kDefaultRelayUrl;

/// Normalises user-entered relay URLs:
/// - Trims surrounding whitespace and trailing slashes.
/// - Prepends `https://` when the user omits a scheme on a domain/path
///   (e.g. `relay.example.com/remote-pi` → `https://relay.example.com/remote-pi`), or
///   `http://` for local addresses (`localhost:...`, `127.0.0.1`, `192.168.x.x`, `10.x.x.x`).
/// - Leaves existing schemes (`http://`, `https://`, `ws://`, `wss://`, `ftp://`)
///   and bare single-word tokens without dots (like `foo` or `not-a-url`)
///   untouched so validation rules still reject invalid inputs as expected.
String normalizeRelayUrl(String raw) {
  var s = raw.trim();
  while (s.endsWith('/') && !s.endsWith('://')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.isEmpty || s.contains('://')) {
    return s;
  }
  final hostPart = s.split('/').first;
  final isLocal = hostPart.startsWith('localhost:') ||
      hostPart == 'localhost' ||
      hostPart.startsWith('127.') ||
      hostPart.startsWith('192.168.') ||
      hostPart.startsWith('10.');
  if (isLocal) {
    return 'http://$s';
  }
  // Bare domain with a dot (e.g. relay.example.com/remote-pi) → https://
  if (hostPart.contains('.') && !hostPart.startsWith('.') && !hostPart.endsWith('.')) {
    return 'https://$s';
  }
  return s;
}

/// Translates the canonical HTTP-form relay URL into the WebSocket
/// form expected by the underlying transport. `https://` → `wss://`,
/// `http://` → `ws://`. Pre-existing `ws(s)://` URLs (legacy QR
/// payloads, old peer records) pass through unchanged so the relay
/// mismatch check in `pair_request_flow` can still compare them.
String toWsRelayUrl(String url) {
  final cleaned = normalizeRelayUrl(url);
  if (cleaned.startsWith('https://')) return 'wss://${cleaned.substring(8)}';
  if (cleaned.startsWith('http://')) return 'ws://${cleaned.substring(7)}';
  return cleaned;
}

/// Validates a candidate relay URL the user typed into Settings or
/// the onboarding form.
///
/// Rules:
/// - Non-empty.
/// - Scheme must be `http://` or `https://` (or a bare domain that
///   [normalizeRelayUrl] promotes to `http(s)://`). Returns `false` (with the
///   ws/wss-specific reason via [relayUrlValidationMessage]) for the
///   legacy `ws://` / `wss://` schemes — the app converts internally.
/// - Must be parseable by `Uri.parse` AND yield a non-empty `host`.
bool isValidRelayUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
    return false;
  }
  final normalized = normalizeRelayUrl(trimmed);
  if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
    return false;
  }
  final Uri uri;
  try {
    uri = Uri.parse(normalized);
  } catch (_) {
    return false;
  }
  if (uri.host.isEmpty) return false;
  return true;
}

/// Returns the user-facing rejection message for [url]. Returns `null`
/// when the URL is valid. Distinguishes the ws/wss case (specific
/// hint about internal conversion) from generic invalid scheme /
/// malformed input.
String? relayUrlValidationMessage(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return kRelayUrlInvalidGeneric;
  if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
    return kRelayUrlInvalidScheme;
  }
  if (isValidRelayUrl(trimmed)) return null;
  return kRelayUrlInvalidGeneric;
}
