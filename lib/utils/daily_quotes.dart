// daily_quotes.dart

class DailyQuotes {
  static const List<String> low = [
    "Every class you attend from here changes the outcome.",
    "Missing now costs more than showing up.",
    "Today’s attendance matters more than yesterday’s."
  ];

  static const List<String> mid = [
    "Consistency is the only thing between you and safety.",
    "You’re closer than you think. Stay sharp.",
    "Show up now so you don’t regret it later."
  ];

  static const List<String> high = [
    "Good discipline creates breathing room.",
    "You’re building a safety net. Don’t stop.",
    "Momentum looks good. Keep it steady."
  ];

  static String getDailyQuote(double percent) {
    final daySeed = DateTime.now().day;
    final list = percent < 60
        ? low
        : percent < 80
        ? mid
        : high;

    return list[daySeed % list.length];
  }
}
