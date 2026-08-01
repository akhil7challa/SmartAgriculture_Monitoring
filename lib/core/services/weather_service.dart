import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/rain_forecast.dart';

class WeatherService {
  static const String _apiKey = '0cc2eb227243462b9d39f09d190eb772';

  Future<RainForecast?> getRainForecast({
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

      int? firstRainIndex;

      for (int i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final pop = ((item['pop'] ?? 0) as num).toDouble() * 100.0;
        final rain = item['rain'] as Map<String, dynamic>?;
        final rainMm = ((rain?['3h'] ?? 0) as num).toDouble();

        if (pop > 0 || rainMm > 0) {
          firstRainIndex = i;
          break;
        }
      }

      if (firstRainIndex == null) {
        final first = list.first as Map<String, dynamic>;
        final dt = (first['dt'] as num).toInt();
        final weatherList = first['weather'] as List<dynamic>?;
        final summary = weatherList != null && weatherList.isNotEmpty
            ? (weatherList.first['description'] ?? 'No rain expected')
                .toString()
            : 'No rain expected';

        final start = DateTime.fromMillisecondsSinceEpoch(dt * 1000);

        return RainForecast(
          chanceOfRain: (((first['pop'] ?? 0) as num).toDouble() * 100.0),
          expectedRainMm: 0,
          startTime: start,
          endTime: start.add(const Duration(hours: 3)),
          summary: summary,
        );
      }

      double maxChance = 0;
      double totalRainMm = 0;
      DateTime? startTime;
      DateTime? endTime;
      String summary = 'Rain forecast';

      for (int i = firstRainIndex; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final pop = ((item['pop'] ?? 0) as num).toDouble() * 100.0;
        final rain = item['rain'] as Map<String, dynamic>?;
        final rainMm = ((rain?['3h'] ?? 0) as num).toDouble();

        final isRainy = pop > 0 || rainMm > 0;

        if (!isRainy && startTime != null) {
          break;
        }

        if (isRainy) {
          final dt = (item['dt'] as num).toInt();
          final slotStart = DateTime.fromMillisecondsSinceEpoch(dt * 1000);
          final slotEnd = slotStart.add(const Duration(hours: 3));

          startTime ??= slotStart;
          endTime = slotEnd;

          if (pop > maxChance) {
            maxChance = pop;
          }

          totalRainMm += rainMm;

          final weatherList = item['weather'] as List<dynamic>?;
          if (weatherList != null && weatherList.isNotEmpty) {
            summary = (weatherList.first['description'] ?? 'Rain forecast')
                .toString();
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
