class WeatherForecastBundle {
  final List<WeatherForecastItem> items;

  WeatherForecastBundle({
    required this.items,
  });
}

class WeatherForecastItem {
  final DateTime dateTime;
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final int pressure;
  final int cloudiness;
  final double windSpeed;
  final int rainChance;
  final double rainVolumeMm;
  final String mainCondition;
  final String description;

  WeatherForecastItem({
    required this.dateTime,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.pressure,
    required this.cloudiness,
    required this.windSpeed,
    required this.rainChance,
    required this.rainVolumeMm,
    required this.mainCondition,
    required this.description,
  });
}

class DailyWeatherSummary {
  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final int averageRainChance;
  final double totalRainMm;
  final double averageWindSpeed;
  final String condition;
  final String description;

  DailyWeatherSummary({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.averageRainChance,
    required this.totalRainMm,
    required this.averageWindSpeed,
    required this.condition,
    required this.description,
  });
}
