import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../core/services/weather_service.dart';
import '../../models/device.dart';
import '../../models/farm.dart';
import '../../models/rain_forecast.dart';
import '../../models/telemetry.dart';
import '../../models/weather_bundle.dart';
import '../../models/zone.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class ZoneDashboardInfo {
  final Farm farm;
  final Zone zone;
  final List<Device> devices;
  final Map<String, dynamic>? schedule;
  final List<Telemetry> telemetryList;

  ZoneDashboardInfo({
    required this.farm,
    required this.zone,
    required this.devices,
    required this.schedule,
    required this.telemetryList,
  });
}

class FarmWeatherInfo {
  final Farm farm;
  final RainForecast? forecast;
  final String? placeName;
  final WeatherForecastBundle? forecastBundle;
  final List<WeatherForecastItem> todayForecast;
  final List<DailyWeatherSummary> dailySummaries;

  FarmWeatherInfo({
    required this.farm,
    required this.forecast,
    required this.placeName,
    required this.forecastBundle,
    required this.todayForecast,
    required this.dailySummaries,
  });
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final WeatherService _weatherService = WeatherService();

  bool _isLoading = true;

  int totalFarms = 0;
  int totalZones = 0;
  int totalDevices = 0;
  int totalScheduledZones = 0;
  int farmsExpectingRain = 0;

  List<ZoneDashboardInfo> zoneInfos = [];
  List<FarmWeatherInfo> farmWeatherInfos = [];

  static const Color _bg = Color(0xFF0B1220);
  static const Color _card = Color(0xFF111827);
  static const Color _cardSoft = Color(0xFF1F2937);
  static const Color _border = Color(0xFF243041);
  static const Color _textPrimary = Color(0xFFF9FAFB);
  static const Color _textSecondary = Color(0xFF9CA3AF);
  static const Color _accentGreen = Color(0xFF22C55E);
  static const Color _accentBlue = Color(0xFF38BDF8);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _accentRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  bool _isRainExpected(RainForecast? forecast) {
    if (forecast == null) return false;
    return forecast.chanceOfRain >= 20 || forecast.expectedRainMm > 0;
  }

  String _timeSegmentDetailed() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 6) return 'sunrise_light';
    if (hour >= 6 && hour < 8) return 'sunrise_full';
    if (hour >= 8 && hour < 16) return 'midday';
    if (hour >= 16 && hour < 17) return 'sunset_light';
    if (hour >= 17 && hour < 19) return 'sunset_full';
    return 'night';
  }

  String _heroImageForWeather(WeatherForecastItem? item) {
    final main = (item?.mainCondition ?? '').toLowerCase().trim();
    final desc = (item?.description ?? '').toLowerCase().trim();
    final rainChance = item?.rainChance ?? 0;
    final time = _timeSegmentDetailed();

    if (main.contains('thunder') || desc.contains('thunder')) {
      return "https://images.unsplash.com/photo-1605727216801-e27ce1d0cc28?auto=format&fit=crop&w=1400&q=80";
    }

    if (main.contains('snow') || desc.contains('snow')) {
      return "https://images.unsplash.com/photo-1483664852095-d6cc6870702d?auto=format&fit=crop&w=1400&q=80";
    }

    if (desc.contains('fog') ||
        desc.contains('mist') ||
        desc.contains('haze')) {
      return "https://images.unsplash.com/photo-1487621167305-5d248087c724?auto=format&fit=crop&w=1400&q=80";
    }

    if (desc.contains('heavy rain') ||
        desc.contains('moderate rain') ||
        desc.contains('very heavy rain') ||
        desc.contains('extreme rain') ||
        rainChance >= 70) {
      return "https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?auto=format&fit=crop&w=1400&q=80";
    }

    if (desc.contains('light rain') ||
        desc.contains('drizzle') ||
        main.contains('rain') ||
        rainChance >= 20) {
      return "https://images.unsplash.com/photo-1501691223387-dd0500403074?auto=format&fit=crop&w=1400&q=80";
    }

    if (desc.contains('overcast')) {
      return "https://images.unsplash.com/photo-1499346030926-9a72daac6c63?auto=format&fit=crop&w=1400&q=80";
    }

    if (desc.contains('broken clouds') || desc.contains('scattered clouds')) {
      return "https://images.unsplash.com/photo-1534088568595-a066f410bcda?auto=format&fit=crop&w=1400&q=80";
    }

    if (desc.contains('few clouds') || main.contains('cloud')) {
      return "https://images.unsplash.com/photo-1504608524841-42fe6f032b4b?auto=format&fit=crop&w=1400&q=80";
    }

    if (main.contains('clear') ||
        desc.contains('clear') ||
        desc.contains('sunny')) {
      if (time == 'sunrise_light') {
        return "https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=1400&q=80";
      }
      if (time == 'sunrise_full') {
        return "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1400&q=80";
      }
      if (time == 'midday') {
        return "https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1400&q=80";
      }
      if (time == 'sunset_light') {
        return "https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=1400&q=80";
      }
      if (time == 'sunset_full') {
        return "https://images.unsplash.com/photo-1501973801540-537f08ccae7b?auto=format&fit=crop&w=1400&q=80";
      }
      return "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1400&q=80";
    }

    if (time == 'sunrise_light') {
      return "https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=1400&q=80";
    }
    if (time == 'sunrise_full') {
      return "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1400&q=80";
    }
    if (time == 'midday') {
      return "https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1400&q=80";
    }
    if (time == 'sunset_light') {
      return "https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=1400&q=80";
    }
    if (time == 'sunset_full') {
      return "https://images.unsplash.com/photo-1501973801540-537f08ccae7b?auto=format&fit=crop&w=1400&q=80";
    }
    return "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1400&q=80";
  }

  Future<FarmWeatherInfo> _loadFarmWeatherInfo(Farm farm) async {
    final results = await Future.wait<dynamic>([
      _weatherService.getForecastBundle(
        latitude: farm.latitude,
        longitude: farm.longitude,
      ),
      _weatherService.getPlaceNameFromCoordinates(
        latitude: farm.latitude,
        longitude: farm.longitude,
      ),
    ]);

    final forecastBundle = results[0] as WeatherForecastBundle?;
    final placeName = results[1] as String?;
    final rainForecast =
        _weatherService.getRainForecastFromBundle(forecastBundle);

    return FarmWeatherInfo(
      farm: farm,
      forecast: rainForecast,
      placeName: placeName,
      forecastBundle: forecastBundle,
      todayForecast: _weatherService.getTodayForecastItems(forecastBundle),
      dailySummaries: _weatherService.getDailySummaries(forecastBundle),
    );
  }

  Future<void> _loadDashboardData() async {
    try {
      final farms = await _firebaseService.getAllFarms();

      final loadedFarmWeatherInfos = await Future.wait(
        farms.map((farm) => _loadFarmWeatherInfo(farm)),
      );

      final rainyFarmsCount = loadedFarmWeatherInfos
          .where((item) => _isRainExpected(item.forecast))
          .length;

      final List<ZoneDashboardInfo> loadedZoneInfos = [];
      int zonesCount = 0;
      int devicesCount = 0;
      int scheduledZonesCount = 0;

      for (final farm in farms) {
        final zones = await _firebaseService.getZones(farm.id);
        zonesCount += zones.length;

        for (final zone in zones) {
          final results = await Future.wait<dynamic>([
            _firebaseService.getDevicesByFarmAndZone(farm.id, zone.id),
            _firebaseService.getZonePumpSchedule(farm.id, zone.id),
          ]);

          final devices = results[0] as List<Device>;
          final schedule = results[1] as Map<String, dynamic>?;

          devicesCount += devices.length;

          if (schedule != null) {
            scheduledZonesCount++;
          }

          final telemetryResults = await Future.wait(
            devices.map((device) => _firebaseService.getTelemetry(device.id)),
          );

          final telemetryList =
              telemetryResults.whereType<Telemetry>().toList();

          loadedZoneInfos.add(
            ZoneDashboardInfo(
              farm: farm,
              zone: zone,
              devices: devices,
              schedule: schedule,
              telemetryList: telemetryList,
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        totalFarms = farms.length;
        totalZones = zonesCount;
        totalDevices = devicesCount;
        totalScheduledZones = scheduledZonesCount;
        farmsExpectingRain = rainyFarmsCount;
        farmWeatherInfos = loadedFarmWeatherInfos;
        zoneInfos = loadedZoneInfos;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  FarmWeatherInfo? _nextRainFarm() {
    FarmWeatherInfo? best;
    DateTime? bestTime;

    for (final item in farmWeatherInfos) {
      final forecast = item.forecast;
      if (forecast == null) continue;
      if (!_isRainExpected(forecast)) continue;

      if (bestTime == null || forecast.startTime.isBefore(bestTime)) {
        bestTime = forecast.startTime;
        best = item;
      }
    }

    return best;
  }

  FarmWeatherInfo? _selectedFarmWeather() {
    return _nextRainFarm() ??
        (farmWeatherInfos.isNotEmpty ? farmWeatherInfos.first : null);
  }

  String _formatForecastRange(
    DateTime start,
    DateTime end,
    BuildContext context,
  ) {
    final localizations = MaterialLocalizations.of(context);

    final startDate = localizations.formatShortDate(start);
    final startTime = localizations.formatTimeOfDay(
      TimeOfDay(hour: start.hour, minute: start.minute),
    );

    final endDate = localizations.formatShortDate(end);
    final endTime = localizations.formatTimeOfDay(
      TimeOfDay(hour: end.hour, minute: end.minute),
    );

    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return "$startDate, $startTime - $endTime";
    }

    return "$startDate, $startTime - $endDate, $endTime";
  }

  DateTime? _nextWateringDateTime(Map<String, dynamic>? schedule) {
    if (schedule == null) return null;

    final int? startHour = schedule['startHour'] as int?;
    final int? startMinute = schedule['startMinute'] as int?;

    if (startHour == null || startMinute == null) return null;

    final now = DateTime.now();
    DateTime next = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
      startMinute,
    );

    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }

    return next;
  }

  ZoneDashboardInfo? _findNextWateringZone() {
    ZoneDashboardInfo? bestZone;
    DateTime? bestTime;

    for (final info in zoneInfos) {
      final next = _nextWateringDateTime(info.schedule);
      if (next == null) continue;

      if (bestTime == null || next.isBefore(bestTime)) {
        bestTime = next;
        bestZone = info;
      }
    }

    return bestZone;
  }

  String _formatNextWatering(
    Map<String, dynamic>? schedule,
    BuildContext context,
  ) {
    final next = _nextWateringDateTime(schedule);
    if (next == null) return "Not scheduled";

    final now = DateTime.now();
    final dayLabel = next.day == now.day ? "Today" : "Tomorrow";

    final localizations = MaterialLocalizations.of(context);
    final timeLabel = localizations.formatTimeOfDay(
      TimeOfDay(hour: next.hour, minute: next.minute),
    );

    return "$dayLabel, $timeLabel";
  }

  String _formatDurationMinutes(Map<String, dynamic>? schedule) {
    if (schedule == null) return "N/A";

    final int? onMinutes = schedule['onMinutes'] as int?;
    if (onMinutes == null) return "N/A";

    if (onMinutes >= 60 && onMinutes % 60 == 0) {
      final hours = onMinutes ~/ 60;
      return "$hours hour${hours > 1 ? 's' : ''}";
    }

    if (onMinutes > 60) {
      final hours = onMinutes ~/ 60;
      final minutes = onMinutes % 60;
      return "${hours}h ${minutes}m";
    }

    return "$onMinutes minutes";
  }

  double _averageTemperature(List<Telemetry> telemetryList) {
    if (telemetryList.isEmpty) return 0;
    final total = telemetryList
        .map((t) => t.temperature.toDouble())
        .reduce((a, b) => a + b);
    return total / telemetryList.length;
  }

  double _averageHumidity(List<Telemetry> telemetryList) {
    if (telemetryList.isEmpty) return 0;
    final total =
        telemetryList.map((t) => t.humidity.toDouble()).reduce((a, b) => a + b);
    return total / telemetryList.length;
  }

  double _averageSoilMoisture(List<Telemetry> telemetryList) {
    if (telemetryList.isEmpty) return 0;
    final total = telemetryList
        .map((t) => t.soilMoisture.toDouble())
        .reduce((a, b) => a + b);
    return total / telemetryList.length;
  }

  int _latestLastSeen(List<Telemetry> telemetryList) {
    if (telemetryList.isEmpty) return 0;
    return telemetryList.map((t) => t.lastSeen).reduce((a, b) => a > b ? a : b);
  }

  int _healthScore(List<Telemetry> telemetryList) {
    if (telemetryList.isEmpty) return 0;

    final temp = _averageTemperature(telemetryList);
    final humidity = _averageHumidity(telemetryList);
    final soil = _averageSoilMoisture(telemetryList);
    final lastSeen = _latestLastSeen(telemetryList);

    double score = 100;

    if (temp < 18 || temp > 38) score -= 15;
    if (humidity < 35 || humidity > 85) score -= 10;
    if (soil < 35) score -= 20;
    if (soil > 85) score -= 10;

    final now = DateTime.now();
    final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen * 1000);
    final difference = now.difference(lastSeenDate);

    if (difference.inMinutes > 30 && difference.inMinutes <= 60) score -= 10;
    if (difference.inMinutes > 60) score -= 25;

    return score.clamp(0, 100).round();
  }

  String _healthStatus(int score) {
    if (score >= 85) return "Healthy";
    if (score >= 70) return "Good";
    if (score >= 50) return "Warning";
    return "Critical";
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return "Mon";
      case DateTime.tuesday:
        return "Tue";
      case DateTime.wednesday:
        return "Wed";
      case DateTime.thursday:
        return "Thu";
      case DateTime.friday:
        return "Fri";
      case DateTime.saturday:
        return "Sat";
      case DateTime.sunday:
        return "Sun";
      default:
        return "";
    }
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF22C55E);
    if (score >= 70) return const Color(0xFF84CC16);
    if (score >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  IconData _weatherIcon(String condition) {
    final c = condition.toLowerCase();

    if (c.contains('thunder')) return Icons.thunderstorm_rounded;
    if (c.contains('drizzle')) return Icons.grain_rounded;
    if (c.contains('rain')) return Icons.grain_rounded;
    if (c.contains('cloud')) return Icons.cloud_rounded;
    if (c.contains('clear') || c.contains('sunny'))
      return Icons.wb_sunny_rounded;
    if (c.contains('snow')) return Icons.ac_unit_rounded;
    if (c.contains('mist') || c.contains('fog') || c.contains('haze')) {
      return Icons.blur_on_rounded;
    }
    return Icons.wb_cloudy_rounded;
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Good Morning, Akhil! 👋",
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Here’s what’s happening across your farms today.",
                style: TextStyle(
                  color: _textSecondary.withOpacity(0.9),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroWeatherCard() {
    final selectedFarm = _selectedFarmWeather();
    final firstForecastItem =
        selectedFarm?.forecastBundle?.items.isNotEmpty == true
            ? selectedFarm!.forecastBundle!.items.first
            : null;

    final farmName = selectedFarm?.farm.name ?? "No farm selected";
    final area = selectedFarm?.placeName ?? "Location unavailable";
    final tempText = firstForecastItem != null
        ? "${firstForecastItem.temperature.toStringAsFixed(0)}°C"
        : "--";
    final subtitle = firstForecastItem != null
        ? (firstForecastItem.description.isNotEmpty
            ? firstForecastItem.description
            : firstForecastItem.mainCondition)
        : "No weather data";

    final heroImage = _heroImageForWeather(firstForecastItem);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: DecorationImage(
          image: NetworkImage(heroImage),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              Colors.black.withOpacity(0.60),
              Colors.black.withOpacity(0.25),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 760;

            return isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroLeft(
                        farmName,
                        area,
                        tempText,
                        subtitle,
                        firstForecastItem?.mainCondition,
                      ),
                      const SizedBox(height: 20),
                      _heroRight(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _heroLeft(
                          farmName,
                          area,
                          tempText,
                          subtitle,
                          firstForecastItem?.mainCondition,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: _heroRight(),
                      ),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _heroLeft(
    String farmName,
    String area,
    String tempText,
    String subtitle,
    String? condition,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          farmName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          area,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              _weatherIcon(condition ?? ''),
              color: Colors.white,
              size: 52,
            ),
            const SizedBox(width: 14),
            Text(
              tempText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _heroRight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentGreen,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "Live",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _glassMetric("Farms", "$totalFarms"),
            _glassMetric("Zones", "$totalZones"),
            _glassMetric("Devices", "$totalDevices"),
            _glassMetric("Scheduled", "$totalScheduledZones"),
          ],
        ),
      ],
    );
  }

  Widget _glassMetric(String label, String value) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStats() {
    final allTelemetry = zoneInfos.expand((z) => z.telemetryList).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 600) crossAxisCount = 2;
        if (constraints.maxWidth > 1000) crossAxisCount = 4;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _miniStatCard(
              icon: Icons.thermostat_rounded,
              iconColor: _accentRed,
              title: "Avg. Temperature",
              value:
                  "${_averageTemperature(allTelemetry).toStringAsFixed(1)}°C",
              status: "Normal",
              statusColor: _accentGreen,
            ),
            _miniStatCard(
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF60A5FA),
              title: "Avg. Humidity",
              value: "${_averageHumidity(allTelemetry).toStringAsFixed(0)}%",
              status: "Normal",
              statusColor: _accentGreen,
            ),
            _miniStatCard(
              icon: Icons.eco_rounded,
              iconColor: _accentGreen,
              title: "Avg. Soil Moisture",
              value:
                  "${_averageSoilMoisture(allTelemetry).toStringAsFixed(0)}%",
              status: "Good",
              statusColor: _accentGreen,
            ),
            _miniStatCard(
              icon: Icons.sensors_rounded,
              iconColor: const Color(0xFF34D399),
              title: "Active Sensors",
              value: "$totalDevices",
              status: "Online",
              statusColor: _accentGreen,
            ),
          ],
        );
      },
    );
  }

  Widget _miniStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1200) {
          return Column(
            children: [
              _buildRainInfoCard(),
              const SizedBox(height: 16),
              _buildNextWateringHighlight(),
              const SizedBox(height: 16),
              _buildWeatherDetailsCard(),
              const SizedBox(height: 16),
              _buildFiveDayForecastCard(),
              const SizedBox(height: 16),
              _buildZoneHighlightsGridSingleColumn(),
            ],
          );
        }

        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildRainInfoCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildNextWateringHighlight()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildWeatherDetailsCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFiveDayForecastCard()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _panelCard(
                      title: "Best Performing Zone",
                      child: _bestZoneContent(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _panelCard(
                      title: "Needs Attention",
                      child: _needsAttentionContent(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _panelCard(
                      title: "Recommendations",
                      child: _recommendationsContent(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRainInfoCard() {
    final nextRain = _nextRainFarm();

    if (nextRain == null || nextRain.forecast == null) {
      return _panelCard(
        title: "Rain Forecast Details",
        child: const Text(
          "No rain forecast available for tracked farms.",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 15,
          ),
        ),
      );
    }

    final forecast = nextRain.forecast!;

    return _panelCard(
      title: "Rain Forecast Details",
      trailing: const Text(
        "Today",
        style: TextStyle(
          color: _accentGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${forecast.chanceOfRain.toStringAsFixed(0)}% chance of rain",
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _softChip(
                Icons.location_on_outlined,
                nextRain.placeName ?? "Unknown area",
              ),
              _softChip(
                Icons.water_drop_outlined,
                "${forecast.expectedRainMm.toStringAsFixed(1)} mm expected",
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow("Farm", nextRain.farm.name),
          _detailRow("Area", nextRain.placeName ?? "Unknown"),
          _detailRow(
            "Rain Window",
            _formatForecastRange(
              forecast.startTime,
              forecast.endTime,
              context,
            ),
          ),
          _detailRow("Summary", forecast.summary),
        ],
      ),
    );
  }

  Widget _buildNextWateringHighlight() {
    final nextZone = _findNextWateringZone();

    if (nextZone == null) {
      return _panelCard(
        title: "Next Watering Schedule",
        child: const Text(
          "No watering schedule found.",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 15,
          ),
        ),
      );
    }

    final healthScore = _healthScore(nextZone.telemetryList);

    return _panelCard(
      title: "Next Watering Schedule",
      trailing: Text(
        _healthStatus(healthScore),
        style: TextStyle(
          color: _scoreColor(healthScore),
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatNextWatering(nextZone.schedule, context),
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _detailRow("Farm", nextZone.farm.name),
          _detailRow("Zone", nextZone.zone.name),
          _detailRow("Devices", nextZone.devices.length.toString()),
          _detailRow("Duration", _formatDurationMinutes(nextZone.schedule)),
          _detailRow("Mode", (nextZone.schedule?['mode'] ?? 'N/A').toString()),
          _detailRow("Health", "$healthScore%"),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailsCard() {
    final selectedFarm = _selectedFarmWeather();

    if (selectedFarm == null) {
      return _panelCard(
        title: "Weather Details",
        child: const Text(
          "No weather details available.",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 15,
          ),
        ),
      );
    }

    final WeatherForecastItem? currentItem =
        selectedFarm.todayForecast.isNotEmpty
            ? selectedFarm.todayForecast.first
            : (selectedFarm.forecastBundle != null &&
                    selectedFarm.forecastBundle!.items.isNotEmpty
                ? selectedFarm.forecastBundle!.items.first
                : null);

    if (currentItem == null) {
      return _panelCard(
        title: "Weather Details",
        child: const Text(
          "No weather details available.",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 15,
          ),
        ),
      );
    }

    return _panelCard(
      title: "Weather Details",
      trailing: const Text(
        "Current",
        style: TextStyle(
          color: _accentGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _weatherIcon(currentItem.mainCondition),
                color: _accentAmber,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  currentItem.description.isNotEmpty
                      ? currentItem.description
                      : currentItem.mainCondition,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _weatherStatBox(
                  label: "Temperature",
                  value: "${currentItem.temperature.toStringAsFixed(1)}°C",
                  icon: Icons.thermostat_rounded,
                  color: _accentRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _weatherStatBox(
                  label: "Humidity",
                  value: "${currentItem.humidity}%",
                  icon: Icons.water_drop_rounded,
                  color: const Color(0xFF60A5FA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _weatherStatBox(
                  label: "Wind",
                  value: "${currentItem.windSpeed.toStringAsFixed(1)} m/s",
                  icon: Icons.air_rounded,
                  color: const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _weatherStatBox(
                  label: "Rain Chance",
                  value: "${currentItem.rainChance}%",
                  icon: Icons.umbrella_rounded,
                  color: const Color(0xFF818CF8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherStatBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _cardSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiveDayForecastCard() {
    final selectedFarm = _selectedFarmWeather();

    if (selectedFarm == null || selectedFarm.dailySummaries.isEmpty) {
      return _panelCard(
        title: "5 Day Forecast",
        child: const Text(
          "No daily forecast available.",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 15,
          ),
        ),
      );
    }

    final items = selectedFarm.dailySummaries.take(5).toList();

    return _panelCard(
      title: "5 Day Forecast",
      trailing: Text(
        selectedFarm.placeName ?? "",
        style: const TextStyle(
          color: _accentGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];

          return Column(
            children: [
              _forecastStyledRow(
                day: _weekdayShort(item.date.weekday),
                icon: _weatherIcon(item.condition),
                max: item.maxTemp.round(),
                min: item.minTemp.round(),
                rainChance: item.averageRainChance,
                condition: item.condition,
              ),
              if (index != items.length - 1) ...[
                const SizedBox(height: 14),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: _border,
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _forecastStyledRow({
    required String day,
    required IconData icon,
    required int max,
    required int min,
    required int rainChance,
    required String condition,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            day,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          icon,
          color: _accentAmber,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$max° / $min°",
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                condition,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          "$rainChance%",
          style: const TextStyle(
            color: _accentBlue,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _bestZoneContent() {
    if (zoneInfos.isEmpty) {
      return const Text(
        "No zone data available.",
        style: TextStyle(
          color: _textSecondary,
          fontSize: 15,
        ),
      );
    }

    final sorted = [...zoneInfos];
    sorted.sort((a, b) {
      final aScore = _healthScore(a.telemetryList);
      final bScore = _healthScore(b.telemetryList);
      return bScore.compareTo(aScore);
    });

    return _zoneSnapshot(sorted.first);
  }

  Widget _needsAttentionContent() {
    if (zoneInfos.isEmpty) {
      return const Text(
        "No zone data available.",
        style: TextStyle(
          color: _textSecondary,
          fontSize: 15,
        ),
      );
    }

    final sorted = [...zoneInfos];
    sorted.sort((a, b) {
      final aScore = _healthScore(a.telemetryList);
      final bScore = _healthScore(b.telemetryList);
      return bScore.compareTo(aScore);
    });

    return _zoneSnapshot(sorted.last);
  }

  Widget _recommendationsContent() {
    if (zoneInfos.isEmpty) {
      return const Text(
        "No recommendations available.",
        style: TextStyle(
          color: _textSecondary,
          fontSize: 15,
        ),
      );
    }

    final List<ZoneDashboardInfo> weakZones =
        zoneInfos.where((z) => _healthScore(z.telemetryList) < 70).toList();

    weakZones.sort((a, b) {
      final aScore = _healthScore(a.telemetryList);
      final bScore = _healthScore(b.telemetryList);
      return aScore.compareTo(bScore);
    });

    final List<ZoneDashboardInfo> unscheduledZones =
        zoneInfos.where((z) => z.schedule == null).toList();

    final List<Widget> items = [];

    for (final zoneInfo in weakZones.take(2)) {
      final score = _healthScore(zoneInfo.telemetryList);
      items.add(
        _recommendationTile(
          icon: Icons.warning_amber_rounded,
          iconColor: _accentRed,
          title: zoneInfo.zone.name,
          farmName: zoneInfo.farm.name,
          message: "Low health score detected ($score%). Check this zone soon.",
        ),
      );
    }

    for (final zoneInfo in unscheduledZones.take(2)) {
      items.add(
        _recommendationTile(
          icon: Icons.schedule_rounded,
          iconColor: _accentAmber,
          title: zoneInfo.zone.name,
          farmName: zoneInfo.farm.name,
          message: "This zone has no watering schedule configured.",
        ),
      );
    }

    if (farmsExpectingRain > 0) {
      final rainyFarm = _nextRainFarm();
      if (rainyFarm != null) {
        items.add(
          _recommendationTile(
            icon: Icons.cloud_rounded,
            iconColor: _accentBlue,
            title: rainyFarm.farm.name,
            farmName: rainyFarm.placeName ?? "Weather alert",
            message: "Rain is expected soon. Consider delaying irrigation.",
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(
        _recommendationTile(
          icon: Icons.check_circle_rounded,
          iconColor: _accentGreen,
          title: "All Zones",
          farmName: "System Status",
          message: "Everything looks good. No urgent action is required.",
        ),
      );
    }

    return Column(
      children: List.generate(items.length, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 12),
          child: items[index],
        );
      }),
    );
  }

  Widget _recommendationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String farmName,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  farmName,
                  style: const TextStyle(
                    color: _accentBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneHighlightsGridSingleColumn() {
    return Column(
      children: [
        _panelCard(
          title: "Best Performing Zone",
          child: _bestZoneContent(),
        ),
        const SizedBox(height: 16),
        _panelCard(
          title: "Needs Attention",
          child: _needsAttentionContent(),
        ),
        const SizedBox(height: 16),
        _panelCard(
          title: "Recommendations",
          child: _recommendationsContent(),
        ),
      ],
    );
  }

  Widget _zoneSnapshot(ZoneDashboardInfo info) {
    final score = _healthScore(info.telemetryList);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.zone.name,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          info.farm.name,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        _detailRow("Health", "${_healthStatus(score)} ($score%)"),
        _detailRow("Devices", info.devices.length.toString()),
        _detailRow(
            "Next Watering", _formatNextWatering(info.schedule, context)),
        if (info.telemetryList.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _softChip(
                Icons.thermostat_rounded,
                "${_averageTemperature(info.telemetryList).toStringAsFixed(1)}°C",
              ),
              _softChip(
                Icons.water_drop_rounded,
                "${_averageHumidity(info.telemetryList).toStringAsFixed(0)}%",
              ),
              _softChip(
                Icons.eco_rounded,
                "${_averageSoilMoisture(info.telemetryList).toStringAsFixed(0)}%",
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _panelCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _cardSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _accentGreen,
        ),
      );
    }

    return Container(
      color: _bg,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildHeroWeatherCard(),
          const SizedBox(height: 20),
          _buildMiniStats(),
          const SizedBox(height: 20),
          _buildDashboardGrid(),
        ],
      ),
    );
  }
}
