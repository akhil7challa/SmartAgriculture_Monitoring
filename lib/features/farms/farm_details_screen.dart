import 'package:flutter/material.dart';

import '../../models/farm.dart';
import '../../models/zone.dart';
import '../../models/device.dart';
import '../../core/services/firebase_service.dart';
import '../devices/device_details_screen.dart';

class FarmDetailsScreen extends StatefulWidget {
  final Farm farm;

  const FarmDetailsScreen({super.key, required this.farm});

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  List<Zone> _zones = [];
  List<Device> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarmData();
  }

  Future<void> _loadFarmData() async {
    final zones = await _firebaseService.getZones(widget.farm.id);
    final devices = await _firebaseService.getDevicesByFarm(widget.farm.id);

    setState(() {
      _zones = zones;
      _devices = devices;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.farm.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.agriculture),
                      title: Text(widget.farm.name),
                      subtitle: Text(widget.farm.location),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Zones',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_zones.isEmpty)
                    const Card(child: ListTile(title: Text('No zones found')))
                  else
                    ..._zones.map(
                      (zone) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.place),
                          title: Text(zone.name),
                          subtitle: Text('Zone ID: ${zone.id}'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Devices',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_devices.isEmpty)
                    const Card(child: ListTile(title: Text('No devices found')))
                  else
                    ..._devices.map(
                      (device) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.memory),
                          title: Text(device.name),
                          subtitle: Text(
                            "Type: ${device.type}\nStatus: ${device.status}\nZone: ${device.zoneId}",
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
