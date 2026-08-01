class RainForecast {
  final double chanceOfRain;
  final double expectedRainMm;
  final DateTime startTime;
  final DateTime endTime;
  final String summary;

  RainForecast({
    required this.chanceOfRain,
    required this.expectedRainMm,
    required this.startTime,
    required this.endTime,
    required this.summary,
  });
}
