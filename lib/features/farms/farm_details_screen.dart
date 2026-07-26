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
                    ..._zones.map(
                      (zone) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.place),
                          title: Text(zone.name),
                          subtitle: Text("Zone ID: ${zone.id}"),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
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
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
