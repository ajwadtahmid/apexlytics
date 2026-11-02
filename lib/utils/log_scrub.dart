import '../constants/api_constants.dart';

/// An error's own text cut down to what is safe to keep, for a log line or a
/// crash report.
///
/// - Only the first line is kept: a [FormatException] prints an excerpt of the
///   text it failed to parse on the lines after it.
/// - A sqflite `DatabaseException` is cut before its ` sql '…' args […]` tail,
///   which quotes the bound arguments (a UID, a player name).
String errorSummary(Object error) {
  var s = error.toString();
  final newline = s.indexOf('\n');
  if (newline >= 0) s = s.substring(0, newline);
  final sql = s.indexOf(" sql '");
  if (sql >= 0) s = s.substring(0, sql);
  return s;
}

/// Removes what must not leave the device in a bug report: UIDs, saved player
/// names, email addresses, the account name inside a file path, and the values
/// of query parameters that carry a player or a key.
///
/// Log calls already follow a rule of never passing these in; this is the
/// second line of defence for the text that rule misses (an exception message
/// quoting a URL, say).
///
/// [names] are exact strings to hide wherever they appear, ignoring case: the
/// saved profiles' names and the favorites'. Ones under 3 characters are
/// skipped, since they would match inside ordinary words.
String scrubForReport(String text, {Iterable<String> names = const []}) {
  var out = text;
  for (final name in names) {
    final trimmed = name.trim();
    if (trimmed.length < 3) continue;
    out = out.replaceAll(
      RegExp(RegExp.escape(trimmed), caseSensitive: false),
      '<name>',
    );
  }
  out = out
      .replaceAllMapped(
        RegExp(
          r'\b(uid|name|player|query|token|key|auth)=[^&\s"]+',
          caseSensitive: false,
        ),
        (m) => '${m[1]}=<redacted>',
      )
      .replaceAll(RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+'), '<email>')
      .replaceAll(ApiConstants.uidPattern, '<uid>')
      .replaceAllMapped(
        RegExp(r'(/home/|/Users/|[A-Za-z]:\\Users\\)[^/\\\s]+'),
        (m) => '${m[1]}<user>',
      );
  return out;
}
