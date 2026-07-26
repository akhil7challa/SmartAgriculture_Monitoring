import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../models/farm.dart';
import '../../models/zone.dart';
import '../zones/zone_details_screen.dart';

class FarmDetailsScreen extends StatefulWidget {
  final Farm farm;

  const FarmDetailsScreen({super.key, required this.farm});

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  List<Zone> _zones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarmData();
  }

  Future<void> _loadFarmData() async {
    final zones = await _firebaseService.getZones(widget.farm.id);

    setState(() {
      _zones = zones;
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
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.agriculture),
                      title: Text(widget.farm.name),
                      subtitle: Text(widget.farm.location),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Zones",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_zones.isEmpty)
                    const Card(child: ListTile(title: Text("No zones found")))
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
                          itemCount: _zones.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.8,
                              ),
                          itemBuilder: (context, index) {
                            final zone = _zones[index];

                            return Card(
                              elevation: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ZoneDetailsScreen(
                                        farm: widget.farm,
                                        zone: zone,
                                      ),
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
                                        Icons.place,
                                        size: 32,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        zone.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Zone ID: ${zone.id}",
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
