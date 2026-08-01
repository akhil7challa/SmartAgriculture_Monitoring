import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../core/services/weather_service.dart';
import '../../models/device.dart';
import '../../models/farm.dart';
import '../../models/rain_forecast.dart';
import '../../models/telemetry.dart';
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

class FarmRainInfo {
  final Farm farm;
  final RainForecast? forecast;
  final String? placeName;

  FarmRainInfo({
    required this.farm,
    required this.forecast,
    required this.placeName,
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
  List<FarmRainInfo> farmRainInfos = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  bool _isRainExpected(RainForecast? forecast) {
    if (forecast == null) return false;
    return forecast.chanceOfRain >= 20 || forecast.expectedRainMm > 0;
  }

  Future<FarmRainInfo> _loadFarmRainInfo(Farm farm) async {
    final results = await Future.wait<dynamic>([
      _weatherService.getRainForecast(
        latitude: farm.latitude,
        longitude: farm.longitude,
      ),
      _weatherService.getPlaceNameFromCoordinates(
        latitude: farm.latitude,
        longitude: farm.longitude,
      ),
    ]);

    return FarmRainInfo(
      farm: farm,
      forecast: results[0] as RainForecast?,
      placeName: results[1] as String?,
    );
  }

  Future<void> _loadDashboardData() async {
    try {
      final farms = await _firebaseService.getAllFarms();

      final loadedFarmRainInfos = await Future.wait(
        farms.map((farm) => _loadFarmRainInfo(farm)),
      );

      final rainyFarmsCount = loadedFarmRainInfos
          .where((item) => _isRainExpected(item.forecast))
          .length;

      List<ZoneDashboardInfo> loadedZoneInfos = [];
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
        farmRainInfos = loadedFarmRainInfos;
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

  FarmRainInfo? _nextRainFarm() {
    FarmRainInfo? best;
    DateTime? bestTime;

    for (final item in farmRainInfos) {
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
    telemetryList.sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
    return telemetryList.last.lastSeen;
  }

  String _timeAgo(int unixTimestamp) {
    if (unixTimestamp == 0) return "No data";

    final now = DateTime.now();
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
    final difference = now.difference(lastSeen);

    if (difference.inSeconds < 60) return "${difference.inSeconds}s ago";
    if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
    if (difference.inHours < 24) return "${difference.inHours}h ago";
    return "${difference.inDays}d ago";
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

  Widget _buildTopCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 700) crossAxisCount = 2;
        if (constraints.maxWidth > 1100) crossAxisCount = 3;
        if (constraints.maxWidth > 1500) crossAxisCount = 5;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 2.6,
          children: [
            _summaryCard(
              title: "Farms",
              value: totalFarms.toString(),
              icon: Icons.agriculture_rounded,
              color: const Color(0xFF4ADE80),
            ),
            _summaryCard(
              title: "Zones",
              value: totalZones.toString(),
              icon: Icons.map_rounded,
              color: const Color(0xFF60A5FA),
            ),
            _summaryCard(
              title: "Devices",
              value: totalDevices.toString(),
              icon: Icons.memory_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _summaryCard(
              title: "Schedules",
              value: totalScheduledZones.toString(),
              icon: Icons.schedule_rounded,
              color: const Color(0xFF22D3EE),
            ),
            _summaryCard(
              title: "Rain Expected",
              value: farmsExpectingRain.toString(),
              icon: Icons.cloud_rounded,
              color: const Color(0xFF38BDF8),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF101A13),
            Color(0xFF0A120D),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
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

  Widget _buildRainInfoCard() {
    final nextRain = _nextRainFarm();

    if (nextRain == null || nextRain.forecast == null) {
      return _highlightCard(
        title: "Rain Forecast Details",
        child: const Text(
          "No rain forecast available for tracked farms",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      );
    }

    final forecast = nextRain.forecast!;

    return _highlightCard(
      title: "Rain Forecast Details",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${forecast.chanceOfRain.toStringAsFixed(0)}% chance of rain",
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip(
                nextRain.placeName ?? "Unknown area",
                const Color(0xFF93C5FD),
              ),
              _metricChip(
                "Lat ${nextRain.farm.latitude.toStringAsFixed(2)}, Lon ${nextRain.farm.longitude.toStringAsFixed(2)}",
                const Color(0xFFCBD5E1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow("Farm", nextRain.farm.name),
          _infoRow("Area", nextRain.placeName ?? "Unknown"),
          _infoRow(
            "Rain Window",
            _formatForecastRange(
              forecast.startTime,
              forecast.endTime,
              context,
            ),
          ),
          _infoRow(
            "Expected Rain",
            "${forecast.expectedRainMm.toStringAsFixed(1)} mm",
          ),
          _infoRow("Summary", forecast.summary),
        ],
      ),
    );
  }

  Widget _buildNextWateringHighlight() {
    final nextZone = _findNextWateringZone();

    if (nextZone == null) {
      return _highlightCard(
        title: "Next Watering Schedule",
        child: const Text(
          "No watering schedule found",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    final healthScore = _healthScore(nextZone.telemetryList);

    return _highlightCard(
      title: "Next Watering Schedule",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatNextWatering(nextZone.schedule, context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow("Farm", nextZone.farm.name),
          _infoRow("Zone", nextZone.zone.name),
          _infoRow("Devices", nextZone.devices.length.toString()),
          _infoRow("Duration", _formatDurationMinutes(nextZone.schedule)),
          _infoRow("Mode", (nextZone.schedule?['mode'] ?? 'N/A').toString()),
          _infoRow(
            "Health",
            "${_healthStatus(healthScore)} ($healthScore%)",
          ),
          if (nextZone.telemetryList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metricChip(
                  "Temp ${_averageTemperature(nextZone.telemetryList).toStringAsFixed(1)}°C",
                  const Color(0xFFFF8A65),
                ),
                _metricChip(
                  "Humidity ${_averageHumidity(nextZone.telemetryList).toStringAsFixed(0)}%",
                  const Color(0xFF4FC3F7),
                ),
                _metricChip(
                  "Soil ${_averageSoilMoisture(nextZone.telemetryList).toStringAsFixed(0)}%",
                  const Color(0xFF81C784),
                ),
                _metricChip(
                  "Updated ${_timeAgo(_latestLastSeen(nextZone.telemetryList))}",
                  const Color(0xFFB39DDB),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoneHighlightsGrid() {
    if (zoneInfos.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = [...zoneInfos];
    sorted.sort((a, b) {
      final aScore = _healthScore(a.telemetryList);
      final bScore = _healthScore(b.telemetryList);
      return bScore.compareTo(aScore);
    });

    final bestZone = sorted.first;
    final weakestZone = sorted.last;

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 900) crossAxisCount = 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 1.5,
          children: [
            _highlightCard(
              title: "Best Performing Zone",
              child: _zoneSnapshot(bestZone),
            ),
            _highlightCard(
              title: "Needs Attention",
              child: _zoneSnapshot(weakestZone),
            ),
          ],
        );
      },
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
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          info.farm.name,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 14),
        _infoRow("Health", "${_healthStatus(score)} ($score%)"),
        _infoRow("Devices", info.devices.length.toString()),
        _infoRow("Next Watering", _formatNextWatering(info.schedule, context)),
        if (info.telemetryList.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip(
                "Temp ${_averageTemperature(info.telemetryList).toStringAsFixed(1)}°C",
                const Color(0xFFFF8A65),
              ),
              _metricChip(
                "Humidity ${_averageHumidity(info.telemetryList).toStringAsFixed(0)}%",
                const Color(0xFF4FC3F7),
              ),
              _metricChip(
                "Soil ${_averageSoilMoisture(info.telemetryList).toStringAsFixed(0)}%",
                const Color(0xFF81C784),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _highlightCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F1720),
            Color(0xFF101A13),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: const Color(0xFF08110C),
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          const Text(
            "Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Smart irrigation insights across all farms and zones",
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          _buildTopCards(),
          const SizedBox(height: 24),
          _buildRainInfoCard(),
          const SizedBox(height: 24),
          _buildNextWateringHighlight(),
          const SizedBox(height: 24),
          _buildZoneHighlightsGrid(),
        ],
      ),
    );
  }
}
