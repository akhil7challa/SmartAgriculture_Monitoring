import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/firebase_service.dart';
import '../../models/device.dart';
import '../../models/telemetry.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailsScreen({super.key, required this.device});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  Timer? _cleanupTimer;
  String? _lastCleanupSlotKey;
  bool _cleanupRunning = false;

  @override
  void initState() {
    super.initState();
    _runCleanupOnce();
    _startScheduledCleanup();
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  Future<void> _runCleanupOnce() async {
    if (_cleanupRunning) return;

    _cleanupRunning = true;
    try {
      await _firebaseService.cleanupOldTelemetryHistory(
        widget.device.id,
        keepLatest: 1000,
      );
    } catch (_) {
      // silent fail
    } finally {
      _cleanupRunning = false;
    }
  }

  void _startScheduledCleanup() {
    _checkAndRunScheduledCleanup();

    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndRunScheduledCleanup();
    });
  }

  Future<void> _checkAndRunScheduledCleanup() async {
    final now = DateTime.now();
    final minute = now.minute;

    final isCleanupMinute =
        minute == 0 || minute == 15 || minute == 30 || minute == 45;

    if (!isCleanupMinute) return;

    final slotKey =
        "${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}";

    if (_lastCleanupSlotKey == slotKey) return;

    _lastCleanupSlotKey = slotKey;
    await _runCleanupOnce();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return const Color(0xFF59E36A);
      case 'offline':
        return const Color(0xFFFF5A5A);
      default:
        return Colors.grey;
    }
  }

  String _formatLastSeen(int unixTimestamp) {
    if (unixTimestamp == 0) return "Unknown";

    final dateTime = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);

    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return "$year-$month-$day $hour:$minute";
  }

  String _timeAgo(int unixTimestamp) {
    if (unixTimestamp == 0) return "Unknown";

    final now = DateTime.now();
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
    final difference = now.difference(lastSeen);

    if (difference.inSeconds < 60) return "${difference.inSeconds}s ago";
    if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
    if (difference.inHours < 24) return "${difference.inHours}h ago";
    return "${difference.inDays}d ago";
  }

  String _soilStatus(double soil) {
    if (soil < 35) return "Needs Water";
    if (soil < 50) return "Needs Water Soon";
    if (soil <= 75) return "Optimal";
    return "Too Wet";
  }

  String _humidityStatus(double humidity) {
    if (humidity < 35) return "Low";
    if (humidity <= 75) return "Excellent";
    return "High";
  }

  String _temperatureStatus(double temp) {
    if (temp < 18) return "Cool";
    if (temp <= 32) return "Optimal";
    if (temp <= 38) return "Warm";
    return "Hot";
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsets? padding,
    BorderRadius? radius,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071A33).withOpacity(0.88),
        borderRadius: radius ?? BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            context.go(
              '/farms/${widget.device.farmId}/zones/${widget.device.zoneId}',
            );
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Expanded(
          child: Text(
            "Device Details",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildHeader(Device device, Telemetry? telemetry) {
    final lastUpdated =
        telemetry == null ? "No data" : _timeAgo(telemetry.lastSeen);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            device.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              "Last data updated",
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              lastUpdated,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArcMetricCard({
    required String title,
    required String value,
    required double percent,
    required Color color,
    required String badge,
    required String change,
    required IconData badgeIcon,
  }) {
    final clamped = percent.clamp(0.0, 1.0);

    return _glassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          SizedBox(
            height: 104,
            width: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 104,
                  width: 104,
                  child: CircularProgressIndicator(
                    value: clamped,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 12, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    badge,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            change,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "vs yesterday",
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart({
    required String title,
    required Color color,
    required List<double> values,
    required List<DateTime> timestamps,
  }) {
    final spots = values.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    final minY = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final maxY = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);

    final adjustedMaxY = maxY == minY ? maxY + 1 : maxY;
    final adjustedMinY = maxY == minY ? minY - 1 : minY;

    return _glassPanel(
      padding: const EdgeInsets.all(16),
      radius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          SizedBox(
            height: 260,
            child: values.isEmpty
                ? const Center(
                    child: Text(
                      "No history data",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (values.length - 1).toDouble(),
                      minY: adjustedMinY,
                      maxY: adjustedMaxY,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();

                              if (index >= timestamps.length) {
                                return null;
                              }

                              final time = timestamps[index];

                              final date =
                                  "${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}";

                              final clock =
                                  "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

                              return LineTooltipItem(
                                "${spot.y.toStringAsFixed(1)}\n$date $clock",
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.white.withOpacity(0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: (adjustedMaxY - adjustedMinY) / 5,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toStringAsFixed(0),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            interval: (values.length / 4)
                                .clamp(1, values.length)
                                .toDouble(),
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();

                              if (index >= timestamps.length) {
                                return const SizedBox();
                              }

                              final time = timestamps[index];

                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  "${time.hour}:${time.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 2.6,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withOpacity(0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricWithChart({
    required Widget metricCard,
    required Widget chart,
  }) {
    return Column(
      children: [
        metricCard,
        const SizedBox(height: 10),
        chart,
      ],
    );
  }

  Widget _buildMetricSections(
    Telemetry? telemetry,
    List<Telemetry> history,
    bool isMobile,
  ) {
    final temp = telemetry?.temperature.toDouble() ?? 0.0;
    final humidity = telemetry?.humidity.toDouble() ?? 0.0;
    final soil = telemetry?.soilMoisture.toDouble() ?? 0.0;

    final temperatureValues =
        history.map((e) => e.temperature.toDouble()).toList();
    final humidityValues = history.map((e) => e.humidity.toDouble()).toList();
    final soilValues = history.map((e) => e.soilMoisture.toDouble()).toList();
    final timestamps = history
        .map((e) => DateTime.fromMillisecondsSinceEpoch(e.lastSeen * 1000))
        .toList();

    final temperatureSection = _buildMetricWithChart(
      metricCard: _buildArcMetricCard(
        title: "Temperature",
        value: "${temp.toStringAsFixed(1)}°c",
        percent: temp / 50,
        color: const Color(0xFFFF8A2A),
        badge: _temperatureStatus(temp),
        change: "+1.2°",
        badgeIcon: Icons.check_circle,
      ),
      chart: _buildTrendChart(
        title: "Temperature Trend",
        color: const Color(0xFFFF8A2A),
        values: temperatureValues,
        timestamps: timestamps,
      ),
    );

    final humiditySection = _buildMetricWithChart(
      metricCard: _buildArcMetricCard(
        title: "Humidity",
        value: "${humidity.toStringAsFixed(0)}%",
        percent: humidity / 100,
        color: const Color(0xFF42B7FF),
        badge: _humidityStatus(humidity),
        change: "-2%",
        badgeIcon: Icons.check_circle,
      ),
      chart: _buildTrendChart(
        title: "Humidity Trend",
        color: const Color(0xFF42B7FF),
        values: humidityValues,
        timestamps: timestamps,
      ),
    );

    final soilSection = _buildMetricWithChart(
      metricCard: _buildArcMetricCard(
        title: "Soil Moisture",
        value: "${soil.toStringAsFixed(0)}%",
        percent: soil / 100,
        color: soil < 45 ? const Color(0xFFFFB347) : const Color(0xFF9AFB65),
        badge: _soilStatus(soil),
        change: soil < 45 ? "-5%" : "+3%",
        badgeIcon: soil < 45 ? Icons.warning_amber_rounded : Icons.check_circle,
      ),
      chart: _buildTrendChart(
        title: "Soil Moisture Trend",
        color: soilValues.isNotEmpty && soilValues.last < 45
            ? const Color(0xFFFFB347)
            : const Color(0xFF7CFC6A),
        values: soilValues,
        timestamps: timestamps,
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          temperatureSection,
          const SizedBox(height: 14),
          humiditySection,
          const SizedBox(height: 14),
          soilSection,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: temperatureSection),
        const SizedBox(width: 12),
        Expanded(child: humiditySection),
        const SizedBox(width: 12),
        Expanded(child: soilSection),
      ],
    );
  }

  Widget _buildMiniCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return _glassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCards(Telemetry? telemetry, bool isMobile) {
    final lastSeenText =
        telemetry == null ? "No data" : _formatLastSeen(telemetry.lastSeen);

    final List<Widget> cards = [
      _buildMiniCard(
        icon: Icons.memory,
        title: "Device",
        value: widget.device.type,
        subtitle: widget.device.status,
        color: _statusColor(widget.device.status),
      ),
      _buildMiniCard(
        icon: Icons.event,
        title: "Last Updated",
        value: telemetry == null ? "--" : _timeAgo(telemetry.lastSeen),
        subtitle: telemetry == null ? "--" : lastSeenText,
        color: const Color(0xFF7AB6FF),
      ),
      _buildMiniCard(
        icon: Icons.location_on,
        title: "Zone",
        value: widget.device.zoneId,
        subtitle: "Assigned Zone",
        color: const Color(0xFFFFB347),
      ),
      _buildMiniCard(
        icon: Icons.agriculture,
        title: "Farm",
        value: widget.device.farmId,
        subtitle: "Assigned Farm",
        color: const Color(0xFF49D0FF),
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.15,
        children: cards,
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 10),
        Expanded(child: cards[1]),
        const SizedBox(width: 10),
        Expanded(child: cards[2]),
        const SizedBox(width: 10),
        Expanded(child: cards[3]),
      ],
    );
  }

  Widget _infoLine(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 12.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo(Device device) {
    return _glassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Device Info",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _infoLine("Type", device.type),
          _infoLine("Farm", device.farmId),
          _infoLine("Zone", device.zoneId),
          _infoLine("ID", device.id),
          _infoLine("Status", device.status,
              color: _statusColor(device.status)),
        ],
      ),
    );
  }

  Widget _buildContent({
    required Device device,
    required Telemetry? telemetry,
    required List<Telemetry> history,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _buildTopBar(),
            const SizedBox(height: 16),
            _buildHeader(device, telemetry),
            const SizedBox(height: 16),
            _buildMetricSections(telemetry, history, isMobile),
            const SizedBox(height: 16),
            _buildBottomCards(telemetry, isMobile),
            const SizedBox(height: 16),
            _buildDeviceInfo(device),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF021225),
              Color(0xFF042041),
              Color(0xFF010A17),
            ],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<Telemetry?>(
            stream: _firebaseService.getTelemetryStream(device.id),
            builder: (context, telemetrySnapshot) {
              if (telemetrySnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Error loading telemetry:\n${telemetrySnapshot.error}",
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return StreamBuilder<List<Telemetry>>(
                stream: _firebaseService.getTelemetryHistoryStream(
                  device.id,
                  limit: 1000,
                ),
                builder: (context, historySnapshot) {
                  if (historySnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "Error loading telemetry history:\n${historySnapshot.error}",
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final telemetry = telemetrySnapshot.data;
                  final history = historySnapshot.data ?? [];

                  final telemetryWaiting = telemetrySnapshot.connectionState ==
                          ConnectionState.waiting &&
                      telemetry == null;

                  final historyWaiting = historySnapshot.connectionState ==
                          ConnectionState.waiting &&
                      history.isEmpty;

                  if (telemetryWaiting || historyWaiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  return _buildContent(
                    device: device,
                    telemetry: telemetry,
                    history: history,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
