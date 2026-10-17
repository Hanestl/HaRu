final _paramTokenRegex = RegExp(
  r'''([?&](?:v-acctoken|acctoken|token|access_token|auth|signature|password|passwd|email)=)[^&#\s"']+''',
  caseSensitive: false,
);

final _phpsessidRegex = RegExp(r'(PHPSESSID=)[^;\s]+', caseSensitive: false);

final _authHeaderRegex = RegExp(
  r'((?:Authorization|X-Api-Key|X-CSRF-TOKEN|X-XSRF-TOKEN|X-Playlist-CSRF)\s*[:=]\s*(?:Bearer\s+)?)[^\s,;]+',
  caseSensitive: false,
);

final _cookieHeaderRegex = RegExp(
  r'(Cookie\s*[:=]\s*)[^\r\n]+',
  caseSensitive: false,
);

final _userPathRegex = RegExp(r'(/user/)\d+', caseSensitive: false);

final _userFieldRegex = RegExp(
  r'((?:用户|user(?:[_-]?Id)?)\s*[:=]\s*)[^；;,\s]+',
  caseSensitive: false,
);

final _jsonFieldRegex = RegExp(
  r'''((?:"?(?:password|passwd|pass|email|api[_-]?key|auth[_-]?key|access[_-]?token|token|secret|signature)"?\s*[:=]\s*)["']?)[^"',;\s&}\]]+''',
  caseSensitive: false,
);

String redactSensitiveText(Object? value, {int maxLength = 600}) {
  var text = value?.toString() ?? '未知错误';
  text = text.replaceAllMapped(
    _paramTokenRegex,
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    _phpsessidRegex,
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    _authHeaderRegex,
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    _cookieHeaderRegex,
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    _userPathRegex,
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    _userFieldRegex,
    (match) => '${match.group(1)}<redacted>',
  );
  text = text.replaceAllMapped(
    _jsonFieldRegex,
    (match) => '${match.group(1)}<redacted>',
  );
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength)}…';
}
