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
                    LayoutBuilder(
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DeviceDetailsScreen(device: device),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                    ),
                ],
              ),
            ),
    );
  }
}
