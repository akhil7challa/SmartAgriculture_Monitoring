import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../models/device.dart';
import '../../models/farm.dart';
import '../../models/zone.dart';
import '../devices/device_details_screen.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final devices = await _firebaseService.getDevicesByFarmAndZone(
      widget.farm.id,
      widget.zone.id,
    );

    setState(() {
      _devices = devices;
      _isLoading = false;
    });
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
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.place),
                      title: Text(widget.zone.name),
                      subtitle: Text(
                        "Farm: ${widget.farm.name}\nZone ID: ${widget.zone.id}",
                      ),
                      isThreeLine: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Devices",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_devices.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text("No devices found in this zone"),
                      ),
                    )
                  else
                    ..._devices.map(
                      (device) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.memory),
                          title: Text(device.name),
                          subtitle: Text(
                            "Type: ${device.type}\n"
                            "Status: ${device.status}\n"
                            "Device ID: ${device.id}",
                          ),
                          isThreeLine: true,
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DeviceDetailsScreen(device: device),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
