/// Basic content moderation utility for filtering inappropriate content.
/// This is required for App Store compliance (Apple Guideline 1.2).
class ContentFilter {
  /// Words that should be filtered from user-generated content.
  /// This list can be expanded with more comprehensive lists.
  static final List<String> _blockedWords = [
    // Turkish profanity
    'amk', 'aq', 'orospu', 'piç', 'siktir', 'yarrak', 'göt', 'pezevenk',
    'ibne', 'kahpe', 'kaltak', 'sürtük', 'gavat', 'dangalak', 'gerizekalı',
    // English profanity
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy', 'cunt', 'bastard',
    'damn', 'whore', 'slut', 'nigger', 'faggot', 'retard',
    // Harassment patterns
    'seni öldürürüm', 'kill you', 'i will kill', 'suicide', 'intihar',
  ];

  /// Check if text contains blocked content.
  /// Returns true if the text is clean (no blocked words found).
  static bool isClean(String text) {
    final lower = text.toLowerCase();
    for (final word in _blockedWords) {
      if (lower.contains(word)) {
        return false;
      }
    }
    return true;
  }

  /// Filter blocked words from text by replacing them with asterisks.
  static String filter(String text) {
    String filtered = text;
    final lower = text.toLowerCase();
    for (final word in _blockedWords) {
      if (lower.contains(word)) {
        // Replace all occurrences (case-insensitive)
        filtered = filtered.replaceAll(
          RegExp(RegExp.escape(word), caseSensitive: false),
          '*' * word.length,
        );
      }
    }
    return filtered;
  }

  /// Get a user-friendly error message when content is blocked.
  static String getBlockedMessage(String lang) {
    if (lang == 'tr') {
      return 'Mesajınız uygunsuz içerik barındırmaktadır. Lütfen topluluk kurallarına uygun bir dil kullanın.';
    }
    return 'Your message contains inappropriate content. Please use language that follows our community guidelines.';
  }
}
