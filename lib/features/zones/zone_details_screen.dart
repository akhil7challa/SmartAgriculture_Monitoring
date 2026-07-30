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

  const ZoneDetailsScreen({
    super.key,
    required this.farm,
    required this.zone,
  });

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
  bool _isSavingSchedule = false;
  bool _isStartingNow = false;

  String _zonePump = "UNKNOWN";
  String _zoneMode = "UNKNOWN";

  TimeOfDay? _startTime;
  Duration _pumpOnDuration = const Duration(minutes: 15);
  bool _repeatDaily = false;

  @override
  void initState() {
    super.initState();
    _loadDevicesAndSubscribe();
    _loadSchedule();
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

  Future<void> _loadSchedule() async {
    try {
      final schedule = await _firebaseService.getZonePumpSchedule(
        widget.farm.id,
        widget.zone.id,
      );

      if (!mounted || schedule == null) return;

      final int? startHour = schedule['startHour'] as int?;
      final int? startMinute = schedule['startMinute'] as int?;
      final int? onMinutes = schedule['onMinutes'] as int?;
      final bool? repeatDaily = schedule['repeatDaily'] as bool?;
      final String? mode = schedule['mode'] as String?;

      setState(() {
        if (startHour != null && startMinute != null) {
          _startTime = TimeOfDay(hour: startHour, minute: startMinute);
        }
        if (onMinutes != null) {
          _pumpOnDuration = Duration(minutes: onMinutes);
        }
        _repeatDaily = repeatDaily ?? false;
        if (mode != null && mode.isNotEmpty) {
          _zoneMode = mode;
        }
      });
    } catch (_) {
      // ignore schedule load errors for now
    }
  }

  Future<void> _setPumpForZone(String command) async {
    if (_devices.isEmpty) return;
    if (_zoneMode.toUpperCase() == "AUTO") return;

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

  Future<void> _toggleMode(bool isManual) async {
    await _setModeForZone(isManual ? "MANUAL" : "AUTO");
  }

  Future<void> _togglePump(bool isOn) async {
    await _setPumpForZone(isOn ? "ON" : "OFF");
  }

  Future<void> _startPumpNow() async {
    if (_devices.isEmpty) return;
    if (_zoneMode.toUpperCase() != "MANUAL") return;

    setState(() {
      _isStartingNow = true;
    });

    try {
      await Future.wait(
        _devices.map((device) {
          return _firebaseService.setPumpCommand(device.id, "ON");
        }),
      );

      if (!mounted) return;

      setState(() {
        _zonePump = "ON";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pump started for all devices in this zone"),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isStartingNow = false;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _pickOnDuration() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      builder: (context) {
        final options = [5, 10, 15, 20, 30, 45, 60, 90, 120];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final minutes = options[index];
                return ListTile(
                  leading: const Icon(Icons.schedule, color: Colors.white70),
                  title: Text(
                    "$minutes minutes",
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, minutes),
                );
              },
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _pumpOnDuration = Duration(minutes: selected);
      });
    }
  }

  Future<void> _saveManualSchedule() async {
    if (_zoneMode.toUpperCase() != "MANUAL") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Switch to MANUAL mode first"),
        ),
      );
      return;
    }

    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a start time"),
        ),
      );
      return;
    }

    setState(() {
      _isSavingSchedule = true;
    });

    try {
      final schedule = {
        "mode": "MANUAL",
        "startHour": _startTime!.hour,
        "startMinute": _startTime!.minute,
        "onMinutes": _pumpOnDuration.inMinutes,
        "repeatDaily": _repeatDaily,
        "farmId": widget.farm.id,
        "zoneId": widget.zone.id,
        "updatedAt": DateTime.now().millisecondsSinceEpoch,
      };

      await _firebaseService.saveZonePumpSchedule(
        widget.farm.id,
        widget.zone.id,
        schedule,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Manual schedule saved successfully"),
          backgroundColor: Colors.blue,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingSchedule = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0 && duration.inMinutes % 60 != 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return "${hours}h ${minutes}m";
    }
    if (duration.inHours > 0 && duration.inMinutes % 60 == 0) {
      return "${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}";
    }
    return "${duration.inMinutes} minutes";
  }

  String _nextWateringText() {
    if (_startTime == null) return "Not scheduled";

    final now = DateTime.now();
    DateTime next = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }

    final dayLabel = next.day == now.day ? "Today" : "Tomorrow";

    final localizations = MaterialLocalizations.of(context);
    final timeLabel = localizations.formatTimeOfDay(
      TimeOfDay(hour: next.hour, minute: next.minute),
    );

    return "$dayLabel, $timeLabel";
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
        return const Color(0xFF4CD964);
      case 'OFF':
        return const Color(0xFF8B94A3);
      default:
        return const Color(0xFF5B6B7A);
    }
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsets? padding,
    BorderRadius? radius,
  }) {
    return Container(
      width: double.infinity,
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
      width: double.infinity,
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

  Widget _buildInfoChip({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInlineControlSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String status,
    required bool switchValue,
    required ValueChanged<bool>? onChanged,
    required bool loading,
  }) {
    final bool disabled = onChanged == null && !loading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: disabled
                      ? Colors.white.withOpacity(0.05)
                      : iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: disabled ? Colors.white38 : iconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: disabled ? Colors.white54 : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Switch(
                      value: switchValue,
                      onChanged: onChanged,
                      activeColor: iconColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoChip(
            text: status,
            color: disabled ? Colors.white38 : iconColor,
          ),
        ],
      ),
    );
  }

  Widget _buildControlsHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            "Controls",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildInfoChip(
          text: "${_devices.length} devices",
          color: const Color(0xFF6EA8FF),
        ),
      ],
    );
  }

  Widget _buildIntegratedControlsRow() {
    final isManual = _zoneMode.toUpperCase() == "MANUAL";
    final isPumpOn = _zonePump.toUpperCase() == "ON";
    final isPumpDisabled = _zoneMode.toUpperCase() == "AUTO" || _isApplyingMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 700;

        final modeSection = _buildInlineControlSection(
          title: "Mode",
          icon: Icons.settings_remote,
          iconColor:
              isManual ? const Color(0xFFFFB347) : const Color(0xFF4DB3FF),
          status: isManual ? "Manual" : "Automatic",
          switchValue: isManual,
          onChanged: _isApplyingMode ? null : _toggleMode,
          loading: _isApplyingMode,
        );

        final pumpSection = _buildInlineControlSection(
          title: "Pump",
          icon: Icons.water_drop_outlined,
          iconColor: _pumpColor(_zonePump),
          status: isPumpOn ? "Running" : "Stopped",
          switchValue: isPumpOn,
          onChanged: isPumpDisabled ? null : _togglePump,
          loading: _isApplyingPump,
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: modeSection),
              const SizedBox(width: 12),
              Expanded(child: pumpSection),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            modeSection,
            const SizedBox(height: 12),
            pumpSection,
          ],
        );
      },
    );
  }

  Widget _scheduleTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF6EA8FF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildManualScheduleCard() {
    final localizations = MaterialLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Schedule Watering",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Set when the pump should start and how long it should stay running",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          _scheduleTile(
            title: "Start Time",
            value: _startTime == null
                ? "Select"
                : localizations.formatTimeOfDay(_startTime!),
            icon: Icons.access_time,
            onTap: _pickStartTime,
          ),
          const SizedBox(height: 10),
          _scheduleTile(
            title: "Run Duration",
            value: _formatDuration(_pumpOnDuration),
            icon: Icons.play_circle_outline,
            onTap: _pickOnDuration,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Repeat Daily",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Run this schedule every day",
                style: TextStyle(color: Colors.white60),
              ),
              value: _repeatDaily,
              onChanged: (value) {
                setState(() {
                  _repeatDaily = value;
                });
              },
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Next Watering",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _nextWateringText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Runs for ${_formatDuration(_pumpOnDuration)} before stopping automatically",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isStartingNow ? null : _startPumpNow,
                  icon: _isStartingNow
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text("Start Now"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSavingSchedule ? null : _saveManualSchedule,
                  icon: _isSavingSchedule
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text("Save Schedule"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D6FFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return _glassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlsHeader(),
          const SizedBox(height: 14),
          _buildIntegratedControlsRow(),
          if (_zoneMode.toUpperCase() == "MANUAL") ...[
            const SizedBox(height: 16),
            _buildManualScheduleCard(),
          ],
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

        if (constraints.maxWidth > 700) crossAxisCount = 2;
        if (constraints.maxWidth > 1100) crossAxisCount = 3;

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

  Widget _buildDevicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Devices",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildDeviceGrid(),
      ],
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1100;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFarmHealthCard(),
                    const SizedBox(height: 16),
                    _buildDevicesSection(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildControlsCard(),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFarmHealthCard(),
            const SizedBox(height: 16),
            _buildControlsCard(),
            const SizedBox(height: 24),
            _buildDevicesSection(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.zone.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  _buildZoneInfoCard(),
                  const SizedBox(height: 24),
                  _buildMainContent(),
                ],
              ),
            ),
    );
  }
}
