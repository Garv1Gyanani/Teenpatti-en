/// Utilities for parsing and formatting shareable Private Room deep links
/// (`?room=XXXXXX`).
abstract final class DeepLinkParser {
  static final RegExp _validRoomCode = RegExp(r'^[A-Za-z0-9]{4,10}$');

  /// Extracts a normalized uppercase 4–10 character room code from a [Uri]'s
  /// query parameters (`?room=XXXXXX` or `?code=XXXXXX`) or hash fragment.
  static String? extractRoomCodeFromUri(Uri? uri) {
    if (uri == null) return null;

    final direct = uri.queryParameters['room'] ?? uri.queryParameters['code'];
    final validatedDirect = _sanitizeCode(direct);
    if (validatedDirect != null) return validatedDirect;

    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      final qIndex = fragment.indexOf('?');
      if (qIndex >= 0 && qIndex + 1 < fragment.length) {
        final queryPart = fragment.substring(qIndex + 1);
        final params = Uri.splitQueryString(queryPart);
        final fromFragment = _sanitizeCode(params['room'] ?? params['code']);
        if (fromFragment != null) return fromFragment;
      }
    }
    return null;
  }

  /// Extracts a room code from a raw route name string (e.g. `/?room=9F7K2D`
  /// or `/private-room?room=AB12CD`).
  static String? extractRoomCodeFromRouteName(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) return null;
    final parsed = Uri.tryParse(routeName.trim());
    return extractRoomCodeFromUri(parsed);
  }

  /// Builds a shareable URL containing `?room=XXXXXX`.
  static String buildShareableRoomUrl(String roomCode, {Uri? baseUri}) {
    final normalized = roomCode.trim().toUpperCase();
    final effectiveBase = baseUri ?? Uri.base;
    if (effectiveBase.scheme == 'http' || effectiveBase.scheme == 'https') {
      return '${effectiveBase.origin}/?room=$normalized';
    }
    return 'https://acesociety.club/?room=$normalized';
  }

  static String? _sanitizeCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().toUpperCase();
    if (_validRoomCode.hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }
}
