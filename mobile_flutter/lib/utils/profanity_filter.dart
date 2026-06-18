class ProfanityFilter {
  static final RegExp _pattern = RegExp(
    r'\b(mierda|pendejo|pendeja|puta|puto|hijueputa|hp|marica|gonorrea|imbecil|idiota|estupido|estúpido|carajo|verga|cul[oó]|chinga|chingar|joder|coño|cabron|cabrona|malparido|hpta|fuck|shit|bitch|asshole|damn|bastard|dick|pussy)\b',
    caseSensitive: false,
    unicode: true,
  );

  static bool containsProfanity(String text) {
    return _pattern.hasMatch(text.toLowerCase());
  }
}
