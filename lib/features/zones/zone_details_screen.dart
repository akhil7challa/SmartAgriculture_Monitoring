import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/firebase_service.dart';
import '../../models/device.dart';
import '../../models/farm.dart';
import '../../models/telemetry.dart';
import '../../models/zone.dart';

class ZoneDetailsScreen extends StatefulWidget {
  final Farm farm;
  final Zone zone;

  const ZoneDetailsScreen({super.key, required this.farm, required this.zone});

  @override
  State<ZoneDetailsScreen> createState() => _ZoneDetailsScreenState();
}

class _ZoneDetailsScreenState extends State<ZoneDetailsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  List<Device> _devices = [];
  Map<String, Telemetry?> _telemetryMap = {};
  final List<StreamSubscription<Telemetry?>> _telemetrySubscriptions = [];

  bool _isLoading = true;
  bool _isApplyingPump = false;
  bool _isApplyingMode = false;

  String _zonePump = "UNKNOWN";
  String _zoneMode = "UNKNOWN";

  @override
  void initState() {
    super.initState();
    _loadDevicesAndSubscribe();
  }

  @override
  void dispose() {
    for (final sub in _telemetrySubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _loadDevicesAndSubscribe() async {
    final devices = await _firebaseService.getDevicesByFarmAndZone(
      widget.farm.id,
      widget.zone.id,
    );

    for (final sub in _telemetrySubscriptions) {
      sub.cancel();
    }
    _telemetrySubscriptions.clear();

    final Map<String, Telemetry?> telemetryMap = {
      for (final device in devices) device.id: null,
    };

    if (!mounted) return;

    setState(() {
      _devices = devices;
      _telemetryMap = telemetryMap;
      _isLoading = false;
    });

    for (final device in devices) {
      final sub = _firebaseService.getTelemetryStream(device.id).listen(
        (telemetry) {
          if (!mounted) return;

          setState(() {
            _telemetryMap[device.id] = telemetry;
          });
        },
        onError: (_) {
          if (!mounted) return;

          setState(() {
            _telemetryMap[device.id] = null;
          });
        },
      );

      _telemetrySubscriptions.add(sub);
    }
  }

  Future<void> _setPumpForZone(String command) async {
    if (_devices.isEmpty) return;

    setState(() {
      _isApplyingPump = true;
    });

    try {
      await Future.wait(
        _devices.map((device) {
          return _firebaseService.setPumpCommand(device.id, command);
        }),
      );

      if (!mounted) return;

      setState(() {
        _zonePump = command;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pump set to $command for all devices in zone"),
          backgroundColor: command == "ON" ? Colors.green : Colors.orange,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isApplyingPump = false;
      });
    }
  }

  Future<void> _setModeForZone(String mode) async {
    if (_devices.isEmpty) return;

    setState(() {
      _isApplyingMode = true;
    });

    try {
      await Future.wait(
        _devices.map((device) {
          return _firebaseService.setMode(device.id, mode);
        }),
      );

      if (!mounted) return;

      setState(() {
        _zoneMode = mode;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Mode set to $mode for all devices in zone"),
          backgroundColor: mode == "AUTO" ? Colors.blue : Colors.deepOrange,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isApplyingMode = false;
      });
    }
  }

  double _averageTemperature() {
    final values = _telemetryMap.values
        .where((t) => t != null)
        .map((t) => t!.temperature.toDouble())
        .toList();

    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _averageHumidity() {
    final values = _telemetryMap.values
        .where((t) => t != null)
        .map((t) => t!.humidity.toDouble())
        .toList();

    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _averageSoilMoisture() {
    final values = _telemetryMap.values
        .where((t) => t != null)
        .map((t) => t!.soilMoisture.toDouble())
        .toList();

    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  int _latestLastSeen() {
    final values = _telemetryMap.values
        .where((t) => t != null && t!.lastSeen > 0)
        .map((t) => t!.lastSeen)
        .toList();

    if (values.isEmpty) return 0;
    values.sort();
    return values.last;
  }

  int _healthScore() {
    final temp = _averageTemperature();
    final humidity = _averageHumidity();
    final soil = _averageSoilMoisture();
    final lastSeen = _latestLastSeen();

    double score = 100;

    if (temp < 18 || temp > 38) score -= 15;
    if (humidity < 35 || humidity > 85) score -= 10;
    if (soil < 35) score -= 20;
    if (soil > 85) score -= 10;

    final freshness = _freshnessLabel(lastSeen);
    if (freshness == "Late") score -= 10;
    if (freshness == "Offline") score -= 25;

    return score.clamp(0, 100).round();
  }

  String _healthStatus(int score) {
    if (score >= 85) return "Healthy";
    if (score >= 70) return "Good";
    if (score >= 50) return "Warning";
    return "Critical";
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

  String _freshnessLabel(int unixTimestamp) {
    if (unixTimestamp == 0) return "Unknown";

    final now = DateTime.now();
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
    final difference = now.difference(lastSeen);

    if (difference.inMinutes <= 30) return "On Schedule";
    if (difference.inMinutes <= 60) return "Late";
    return "Offline";
  }

  Color _pumpColor(String pumpStatus) {
    switch (pumpStatus.toUpperCase()) {
      case 'ON':
        return const Color(0xFF59E36A);
      case 'OFF':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Color _modeColor(String mode) {
    switch (mode.toUpperCase()) {
      case 'AUTO':
        return const Color(0xFF4DB3FF);
      case 'MANUAL':
        return const Color(0xFFFFB347);
      default:
        return Colors.grey;
    }
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

  Widget _greenHealthPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E4D22).withOpacity(0.95),
            const Color(0xFF102B18).withOpacity(0.95),
            const Color(0xFF0A1A12).withOpacity(0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _metricDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  Widget _healthLegendRow({
    required Color color,
    required String label,
    required String value,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _metricDot(color),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 62,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmHealthCard() {
    final score = _healthScore();
    final temp = _averageTemperature();
    final humidity = _averageHumidity();
    final soil = _averageSoilMoisture();
    final lastSeen = _latestLastSeen();

    return _greenHealthPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Zone Health",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Last data updated",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeAgo(lastSeen),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                height: 110,
                width: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 92,
                      width: 92,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 5.5,
                        backgroundColor: Colors.white.withOpacity(0.10),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF6EEB4F),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$score%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _healthStatus(score),
                          style: const TextStyle(
                            color: Color(0xFF9CF77A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _healthLegendRow(
                      color: const Color(0xFFFF6A3D),
                      label: "Temperature",
                      value: "${temp.toStringAsFixed(1)}°C",
                    ),
                    const SizedBox(height: 12),
                    _healthLegendRow(
                      color: const Color(0xFF1FB6FF),
                      label: "Humidity",
                      value: "${humidity.toStringAsFixed(0)}%",
                    ),
                    const SizedBox(height: 12),
                    _healthLegendRow(
                      color: const Color(0xFF67E84A),
                      label: "Soil Moisture",
                      value: "${soil.toStringAsFixed(0)}%",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _segmentButton({
    required String label,
    required IconData icon,
    required bool selected,
    required Color selectedColor,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color:
              selected ? selectedColor.withOpacity(0.18) : Colors.transparent,
          border: Border.all(
            color: selected
                ? selectedColor.withOpacity(0.35)
                : Colors.white.withOpacity(0.04),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            if (loading)
              SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    selected ? selectedColor : Colors.white70,
                  ),
                ),
              )
            else
              Icon(
                icon,
                color: selected ? selectedColor : Colors.white70,
                size: 18,
              ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? selectedColor : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedToggle({
    required String leftLabel,
    required String rightLabel,
    required String selectedValue,
    required Color leftColor,
    required Color rightColor,
    required VoidCallback onLeftTap,
    required VoidCallback onRightTap,
    required IconData leftIcon,
    required IconData rightIcon,
    bool loading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segmentButton(
              label: leftLabel,
              icon: leftIcon,
              selected: selectedValue == leftLabel,
              selectedColor: leftColor,
              onTap: onLeftTap,
              loading: loading && selectedValue == leftLabel,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _segmentButton(
              label: rightLabel,
              icon: rightIcon,
              selected: selectedValue == rightLabel,
              selectedColor: rightColor,
              onTap: onRightTap,
              loading: loading && selectedValue == rightLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return _glassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Controls",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Apply commands to all devices in this zone",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          _controlSectionLabel("Pump Control"),
          const SizedBox(height: 10),
          _buildSegmentedToggle(
            leftLabel: "ON",
            rightLabel: "OFF",
            selectedValue: _zonePump.toUpperCase() == "ON" ? "ON" : "OFF",
            leftColor: const Color(0xFF2BCB5A),
            rightColor: const Color(0xFFFF6B57),
            onLeftTap: () => _setPumpForZone("ON"),
            onRightTap: () => _setPumpForZone("OFF"),
            leftIcon: Icons.play_arrow_rounded,
            rightIcon: Icons.stop_rounded,
            loading: _isApplyingPump,
          ),
          const SizedBox(height: 18),
          _controlSectionLabel("Mode Selection"),
          const SizedBox(height: 10),
          _buildSegmentedToggle(
            leftLabel: "AUTO",
            rightLabel: "MANUAL",
            selectedValue:
                _zoneMode.toUpperCase() == "AUTO" ? "AUTO" : "MANUAL",
            leftColor: const Color(0xFF338DFF),
            rightColor: const Color(0xFFFFB347),
            onLeftTap: () => _setModeForZone("AUTO"),
            onRightTap: () => _setModeForZone("MANUAL"),
            leftIcon: Icons.autorenew_rounded,
            rightIcon: Icons.touch_app_rounded,
            loading: _isApplyingMode,
          ),
          const SizedBox(height: 18),
          Text(
            "Devices in zone: ${_devices.length}",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneInfoCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.place),
        title: Text(widget.zone.name),
        subtitle: Text(
          "Farm: ${widget.farm.name}\nZone ID: ${widget.zone.id}\nDevices: ${_devices.length}",
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildDeviceGrid() {
    if (_devices.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text("No devices found in this zone"),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;

        if (constraints.maxWidth > 700) {
          crossAxisCount = 2;
        }

        if (constraints.maxWidth > 1100) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _devices.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final device = _devices[index];

            return Card(
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  context.go(
                    '/farms/${widget.farm.id}/zones/${widget.zone.id}/devices/${device.id}',
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.memory,
                        size: 32,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text("Type: ${device.type}"),
                      const SizedBox(height: 4),
                      Text("Status: ${device.status}"),
                      const SizedBox(height: 4),
                      Text(
                        "Device ID: ${device.id}",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildFarmHealthCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildControlsCard()),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildFarmHealthCard(),
            const SizedBox(height: 16),
            _buildControlsCard(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.zone.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  _buildZoneInfoCard(),
                  const SizedBox(height: 24),
                  _buildTopSection(),
                  const SizedBox(height: 24),
                  const Text(
                    "Devices",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDeviceGrid(),
                ],
              ),
            ),
    );
  }
}
