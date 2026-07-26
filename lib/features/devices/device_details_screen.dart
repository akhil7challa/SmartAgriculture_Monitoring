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
              child: ListTile(
                leading: const Icon(Icons.memory),
                title: Text(device.name),
                subtitle: Text(
                  "Type: ${device.type}\n"
                  "Status: ${device.status}\n"
                  "Farm: ${device.farmId}\n"
                  "Zone: ${device.zoneId}",
                ),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Live Telemetry",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

                return Column(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.thermostat),
                        title: const Text("Temperature"),
                        trailing: Text("${telemetry.temperature} °C"),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.water_drop),
                        title: const Text("Humidity"),
                        trailing: Text("${telemetry.humidity} %"),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.grass),
                        title: const Text("Soil Moisture"),
                        trailing: Text("${telemetry.soilMoisture}"),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.power),
                        title: const Text("Pump Status"),
                        trailing: Text(telemetry.pumpStatus),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text("Last Seen"),
                        trailing: Text(telemetry.lastSeen.toString()),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Pump Controls",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setPump("ON"),
                    child: const Text("Pump ON"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setPump("OFF"),
                    child: const Text("Pump OFF"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Mode",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  child: ElevatedButton(
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
