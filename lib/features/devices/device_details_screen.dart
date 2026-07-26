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

  Future<void> _setPump(String command) async {
    await _firebaseService.setPumpCommand(widget.device.id, command);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Pump set to $command")));
  }

  Future<void> _setMode(String mode) async {
    await _firebaseService.setMode(widget.device.id, mode);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Mode set to $mode")));
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _pumpColor(String pumpStatus) {
    switch (pumpStatus.toUpperCase()) {
      case 'ON':
        return Colors.green;
      case 'OFF':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Color _modeColor(String mode) {
    switch (mode.toUpperCase()) {
      case 'AUTO':
        return Colors.blue;
      case 'MANUAL':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatLastSeen(int unixTimestamp) {
    if (unixTimestamp == 0) {
      return "Unknown";
    }

    final dateTime = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);

    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');

    return "$year-$month-$day $hour:$minute:$second";
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _telemetryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commandChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    return Scaffold(
      appBar: AppBar(title: Text(device.name)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.memory,
                          size: 32,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            device.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(
                              device.status,
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            device.status.toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(device.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _infoRow("Type", device.type),
                    _infoRow("Farm", device.farmId),
                    _infoRow("Zone", device.zoneId),
                    _infoRow("Device ID", device.id),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Command State",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<Map<String, dynamic>?>(
              stream: _firebaseService.getCommandStream(device.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.error, color: Colors.red),
                      title: const Text("Error loading commands"),
                      subtitle: Text(snapshot.error.toString()),
                    ),
                  );
                }

                final commandData = snapshot.data;

                if (commandData == null) {
                  return const Card(
                    child: ListTile(title: Text("No command state available")),
                  );
                }

                final pump = (commandData["pump"] ?? "UNKNOWN").toString();
                final mode = (commandData["mode"] ?? "UNKNOWN").toString();

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _commandChip(
                          label: "Pump",
                          value: pump,
                          color: _pumpColor(pump),
                        ),
                        _commandChip(
                          label: "Mode",
                          value: mode,
                          color: _modeColor(mode),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Live Telemetry",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<Telemetry?>(
              stream: _firebaseService.getTelemetryStream(device.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.error, color: Colors.red),
                      title: const Text("Error loading telemetry"),
                      subtitle: Text(snapshot.error.toString()),
                    ),
                  );
                }

                final telemetry = snapshot.data;

                if (telemetry == null) {
                  return const Card(
                    child: ListTile(title: Text("No telemetry available")),
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

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.7,
                      children: [
                        _telemetryCard(
                          icon: Icons.thermostat,
                          title: "Temperature",
                          value: "${telemetry.temperature} °C",
                          color: Colors.redAccent,
                        ),
                        _telemetryCard(
                          icon: Icons.water_drop,
                          title: "Humidity",
                          value: "${telemetry.humidity} %",
                          color: Colors.blue,
                        ),
                        _telemetryCard(
                          icon: Icons.grass,
                          title: "Soil Moisture",
                          value: "${telemetry.soilMoisture}",
                          color: Colors.green,
                        ),
                        _telemetryCard(
                          icon: Icons.power,
                          title: "Pump Status",
                          value: telemetry.pumpStatus,
                          color: _pumpColor(telemetry.pumpStatus),
                        ),
                        _telemetryCard(
                          icon: Icons.access_time,
                          title: "Last Seen",
                          value: _formatLastSeen(telemetry.lastSeen),
                          color: Colors.deepPurple,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Pump Controls",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _setPump("ON"),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Pump ON"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setPump("OFF"),
                    icon: const Icon(Icons.stop),
                    label: const Text("Pump OFF"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Mode",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setMode("AUTO"),
                    child: const Text("AUTO"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setMode("MANUAL"),
                    child: const Text("MANUAL"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
