import 'package:html/parser.dart' as html_parser;

/// Converts an HTML fragment to readable plain text.
///
/// Feed descriptions (e.g. Google News RSS) embed markup such as
/// `<a href>…</a>&nbsp;<font color>…`. Rendering that verbatim shows tags to
/// the user, so we parse it and keep only the text (entities decoded).
String stripHtml(String? input) {
  final value = input ?? '';
  if (value.isEmpty) return '';
  // Cheap check: nothing that looks like a tag or entity, return as-is.
  if (!value.contains('<') && !value.contains('&')) return value.trim();
  final text = html_parser.parse(value).body?.text ?? value;
  // Collapse the whitespace left behind by removed block elements.
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
