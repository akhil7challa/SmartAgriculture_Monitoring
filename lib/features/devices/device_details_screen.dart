import 'package:flutter/material.dart';

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

  Widget _iconCircle(IconData icon, Color color) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
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

    return Expanded(
      child: _glassPanel(
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
      ),
    );
  }

  Widget _buildMetricsRow(Telemetry? telemetry, bool isMobile) {
    final temp = telemetry?.temperature.toDouble() ?? 0.0;
    final humidity = telemetry?.humidity.toDouble() ?? 0.0;
    final soil = telemetry?.soilMoisture.toDouble() ?? 0.0;

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              _buildArcMetricCard(
                title: "Temperature",
                value: "${temp.toStringAsFixed(1)}°c",
                percent: temp / 50,
                color: const Color(0xFFFF8A2A),
                badge: _temperatureStatus(temp),
                change: "+1.2°",
                badgeIcon: Icons.check_circle,
              ),
              const SizedBox(width: 12),
              _buildArcMetricCard(
                title: "Humidity",
                value: "${humidity.toStringAsFixed(0)}%",
                percent: humidity / 100,
                color: const Color(0xFF42B7FF),
                badge: _humidityStatus(humidity),
                change: "-2%",
                badgeIcon: Icons.check_circle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildArcMetricCard(
                title: "Soil Moisture",
                value: "${soil.toStringAsFixed(0)}%",
                percent: soil / 100,
                color: soil < 45
                    ? const Color(0xFFFFB347)
                    : const Color(0xFF9AFB65),
                badge: _soilStatus(soil),
                change: soil < 45 ? "-5%" : "+3%",
                badgeIcon: soil < 45
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
              ),
              const Spacer(),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        _buildArcMetricCard(
          title: "Temperature",
          value: "${temp.toStringAsFixed(1)}°c",
          percent: temp / 50,
          color: const Color(0xFFFF8A2A),
          badge: _temperatureStatus(temp),
          change: "+1.2°",
          badgeIcon: Icons.check_circle,
        ),
        const SizedBox(width: 12),
        _buildArcMetricCard(
          title: "Humidity",
          value: "${humidity.toStringAsFixed(0)}%",
          percent: humidity / 100,
          color: const Color(0xFF42B7FF),
          badge: _humidityStatus(humidity),
          change: "-2%",
          badgeIcon: Icons.check_circle,
        ),
        const SizedBox(width: 12),
        _buildArcMetricCard(
          title: "Soil Moisture",
          value: "${soil.toStringAsFixed(0)}%",
          percent: soil / 100,
          color: soil < 45 ? const Color(0xFFFFB347) : const Color(0xFF9AFB65),
          badge: _soilStatus(soil),
          change: soil < 45 ? "-5%" : "+3%",
          badgeIcon:
              soil < 45 ? Icons.warning_amber_rounded : Icons.check_circle,
        ),
      ],
    );
  }

  Widget _buildSoilMoistureCard(Telemetry? telemetry) {
    final soil = telemetry?.soilMoisture.toDouble() ?? 0.0;
    final status = _soilStatus(soil);
    final lineColor =
        soil < 45 ? const Color(0xFFFFB347) : const Color(0xFF7CFC6A);

    return _glassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconCircle(Icons.water_drop, const Color(0xFF4BE2D4)),
              const SizedBox(width: 10),
              const Text(
                "Soil Moisture",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "${soil.toStringAsFixed(0)}%",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(
              color:
                  soil < 45 ? const Color(0xFFFFB347) : const Color(0xFF9AFB65),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            child: CustomPaint(
              size: const Size(double.infinity, 72),
              painter: _SimpleTrendPainter(color: lineColor),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: soil / 100,
              minHeight: 11,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(lineColor),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("0%", style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text("50%",
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text("100%",
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
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
            _buildMetricsRow(telemetry, isMobile),
            const SizedBox(height: 16),
            _buildSoilMoistureCard(telemetry),
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

              final telemetry = telemetrySnapshot.data;
              final telemetryWaiting = telemetrySnapshot.connectionState ==
                      ConnectionState.waiting &&
                  telemetry == null;

              if (telemetryWaiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              return _buildContent(
                device: device,
                telemetry: telemetry,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SimpleTrendPainter extends CustomPainter {
  final Color color;

  _SimpleTrendPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.20),
          color.withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final points = <Offset>[
      Offset(0, size.height * 0.72),
      Offset(size.width * 0.08, size.height * 0.62),
      Offset(size.width * 0.14, size.height * 0.68),
      Offset(size.width * 0.22, size.height * 0.44),
      Offset(size.width * 0.30, size.height * 0.50),
      Offset(size.width * 0.38, size.height * 0.38),
      Offset(size.width * 0.46, size.height * 0.57),
      Offset(size.width * 0.54, size.height * 0.49),
      Offset(size.width * 0.62, size.height * 0.30),
      Offset(size.width * 0.70, size.height * 0.42),
      Offset(size.width * 0.78, size.height * 0.22),
      Offset(size.width * 0.86, size.height * 0.28),
      Offset(size.width * 0.94, size.height * 0.10),
      Offset(size.width, size.height * 0.12),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      final midY = (prev.dy + curr.dy) / 2;
      path.quadraticBezierTo(prev.dx, prev.dy, midX, midY);
    }

    path.lineTo(points.last.dx, points.last.dy);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SimpleTrendPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
