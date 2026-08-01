import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/rain_forecast.dart';
import '../../models/weather_bundle.dart';

class WeatherService {
  static const String _apiKey = '0cc2eb227243462b9d39f09d190eb772';

  Future<WeatherForecastBundle?> getForecastBundle({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast'
        '?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['list'] as List<dynamic>?;

      if (list == null || list.isEmpty) {
        return null;
      }

      final items = list.map((raw) {
        final item = raw as Map<String, dynamic>;
        final main = item['main'] as Map<String, dynamic>? ?? {};
        final weather = item['weather'] as List<dynamic>? ?? [];
        final weatherItem = weather.isNotEmpty
            ? weather.first as Map<String, dynamic>
            : <String, dynamic>{};
        final wind = item['wind'] as Map<String, dynamic>? ?? {};
        final clouds = item['clouds'] as Map<String, dynamic>? ?? {};
        final rain = item['rain'] as Map<String, dynamic>?;

        return WeatherForecastItem(
          dateTime: DateTime.fromMillisecondsSinceEpoch(
            ((item['dt'] ?? 0) as num).toInt() * 1000,
          ),
          temperature: ((main['temp'] ?? 0) as num).toDouble(),
          feelsLike: ((main['feels_like'] ?? 0) as num).toDouble(),
          tempMin: ((main['temp_min'] ?? 0) as num).toDouble(),
          tempMax: ((main['temp_max'] ?? 0) as num).toDouble(),
          humidity: ((main['humidity'] ?? 0) as num).toInt(),
          pressure: ((main['pressure'] ?? 0) as num).toInt(),
          cloudiness: ((clouds['all'] ?? 0) as num).toInt(),
          windSpeed: ((wind['speed'] ?? 0) as num).toDouble(),
          rainChance: ((((item['pop'] ?? 0) as num).toDouble()) * 100).round(),
          rainVolumeMm: ((rain?['3h'] ?? 0) as num).toDouble(),
          mainCondition: (weatherItem['main'] ?? '').toString(),
          description: (weatherItem['description'] ?? '').toString(),
        );
      }).toList();

      return WeatherForecastBundle(items: items);
    } catch (e) {
      return null;
    }
  }

  RainForecast? getRainForecastFromBundle(WeatherForecastBundle? bundle) {
    try {
      final list = bundle?.items;
      if (list == null || list.isEmpty) {
        return null;
      }

      int? firstRainIndex;

      for (int i = 0; i < list.length; i++) {
        final item = list[i];
        if (item.rainChance > 0 || item.rainVolumeMm > 0) {
          firstRainIndex = i;
          break;
        }
      }

      if (firstRainIndex == null) {
        final first = list.first;
        return RainForecast(
          chanceOfRain: first.rainChance.toDouble(),
          expectedRainMm: 0,
          startTime: first.dateTime,
          endTime: first.dateTime.add(const Duration(hours: 3)),
          summary: first.description.isNotEmpty
              ? first.description
              : 'No rain expected',
        );
      }

      double maxChance = 0;
      double totalRainMm = 0;
      DateTime? startTime;
      DateTime? endTime;
      String summary = 'Rain forecast';

      for (int i = firstRainIndex; i < list.length; i++) {
        final item = list[i];
        final isRainy = item.rainChance > 0 || item.rainVolumeMm > 0;

        if (!isRainy && startTime != null) {
          break;
        }

        if (isRainy) {
          final slotStart = item.dateTime;
          final slotEnd = slotStart.add(const Duration(hours: 3));

          startTime ??= slotStart;
          endTime = slotEnd;

          if (item.rainChance > maxChance) {
            maxChance = item.rainChance.toDouble();
          }

          totalRainMm += item.rainVolumeMm;

          if (item.description.isNotEmpty) {
            summary = item.description;
          }
        }
      }

      if (startTime == null || endTime == null) {
        return null;
      }

      return RainForecast(
        chanceOfRain: maxChance,
        expectedRainMm: totalRainMm,
        startTime: startTime,
        endTime: endTime,
        summary: summary,
      );
    } catch (e) {
      return null;
    }
  }

  Future<RainForecast?> getRainForecast({
    required double latitude,
    required double longitude,
  }) async {
    final bundle = await getForecastBundle(
      latitude: latitude,
      longitude: longitude,
    );
    return getRainForecastFromBundle(bundle);
  }

  List<WeatherForecastItem> getTodayForecastItems(
    WeatherForecastBundle? bundle,
  ) {
    if (bundle == null || bundle.items.isEmpty) return [];

    final now = DateTime.now();

    return bundle.items.where((item) {
      return item.dateTime.year == now.year &&
          item.dateTime.month == now.month &&
          item.dateTime.day == now.day;
    }).toList();
  }

  List<DailyWeatherSummary> getDailySummaries(
    WeatherForecastBundle? bundle,
  ) {
    if (bundle == null || bundle.items.isEmpty) return [];

    final Map<String, List<WeatherForecastItem>> grouped = {};

    for (final item in bundle.items) {
      final key =
          '${item.dateTime.year}-${item.dateTime.month}-${item.dateTime.day}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final summaries = grouped.entries.map((entry) {
      final items = entry.value;

      final minTemp =
          items.map((e) => e.tempMin).reduce((a, b) => a < b ? a : b);

      final maxTemp =
          items.map((e) => e.tempMax).reduce((a, b) => a > b ? a : b);

      final avgRainChance =
          (items.map((e) => e.rainChance).reduce((a, b) => a + b) /
                  items.length)
              .round();

      final totalRain =
          items.map((e) => e.rainVolumeMm).reduce((a, b) => a + b);

      final avgWind =
          items.map((e) => e.windSpeed).reduce((a, b) => a + b) / items.length;

      final representative = items.reduce((a, b) {
        return a.rainChance >= b.rainChance ? a : b;
      });

      final firstDate = items.first.dateTime;

      return DailyWeatherSummary(
        date: DateTime(firstDate.year, firstDate.month, firstDate.day),
        minTemp: minTemp,
        maxTemp: maxTemp,
        averageRainChance: avgRainChance,
        totalRainMm: totalRain,
        averageWindSpeed: avgWind,
        condition: representative.mainCondition,
        description: representative.description,
      );
    }).toList();

    summaries.sort((a, b) => a.date.compareTo(b.date));
    return summaries;
  }

  Future<String?> getPlaceNameFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$latitude&lon=$longitude&format=jsonv2',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'smart-irrigation-app',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      if (address == null) {
        return null;
      }

      final city = address['city'] ??
          address['town'] ??
          address['village'] ??
          address['municipality'];
      final state = address['state'];
      final country = address['country'];

      if (city != null && country != null) {
        return '$city, $country';
      }

      if (state != null && country != null) {
        return '$state, $country';
      }

      if (country != null) {
        return country.toString();
      }

      return data['display_name']?.toString();
    } catch (e) {
      return null;
    }
  }
}
