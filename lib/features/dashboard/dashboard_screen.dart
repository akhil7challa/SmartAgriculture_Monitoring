import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../models/device.dart';
import '../../models/farm.dart';
import '../../models/zone.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = true;
  int totalFarms = 0;
  int totalZones = 0;
  int totalDevices = 0;
  int totalOnlineDevices = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final List<Farm> farms = await _firebaseService.getAllFarms();
      final List<Device> devices = await _firebaseService.getAllDevices();

      int zonesCount = 0;

      for (final farm in farms) {
        final List<Zone> zones = await _firebaseService.getZones(farm.id);
        zonesCount += zones.length;
      }

      if (!mounted) return;

      setState(() {
        totalFarms = farms.length;
        totalZones = zonesCount;
        totalDevices = devices.length;
        totalOnlineDevices = 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: const Color(0xFF08110C),
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          const Text(
            "Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Overview of your smart farm system",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 1;

              if (constraints.maxWidth > 700) {
                crossAxisCount = 2;
              }

              if (constraints.maxWidth > 1100) {
                crossAxisCount = 4;
              }

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 2.6,
                children: [
                  DashboardStatCard(
                    title: "Farms",
                    value: totalFarms.toString(),
                    icon: Icons.agriculture_rounded,
                    iconColor: const Color(0xFF4ADE80),
                  ),
                  DashboardStatCard(
                    title: "Zones",
                    value: totalZones.toString(),
                    icon: Icons.map_rounded,
                    iconColor: const Color(0xFF3B82F6),
                  ),
                  DashboardStatCard(
                    title: "Devices",
                    value: totalDevices.toString(),
                    icon: Icons.memory_rounded,
                    iconColor: const Color(0xFFF59E0B),
                  ),
                  DashboardStatCard(
                    title: "Online",
                    value: totalOnlineDevices.toString(),
                    icon: Icons.wifi_rounded,
                    iconColor: const Color(0xFF06B6D4),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF101A13),
            Color(0xFF0A120D),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
