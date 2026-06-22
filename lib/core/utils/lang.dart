/// Language helpers for deciding when to translate foreign articles.

final _hangul = RegExp(r'[가-힣]');

/// Whether [text] contains any Hangul syllables.
bool hasHangul(String text) => _hangul.hasMatch(text);

/// Heuristic: an article needs Korean translation when its title has no Hangul
/// (e.g. it came from an international/English source).
bool needsKoreanTranslation(String title) =>
    title.trim().isNotEmpty && !hasHangul(title);
