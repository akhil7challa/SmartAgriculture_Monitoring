import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../models/farm.dart';
import '../../models/zone.dart';
import 'zone_details_screen.dart';

class ZoneDetailsRouteScreen extends StatefulWidget {
  final String farmId;
  final String zoneId;

  const ZoneDetailsRouteScreen({
    super.key,
    required this.farmId,
    required this.zoneId,
  });

  @override
  State<ZoneDetailsRouteScreen> createState() => _ZoneDetailsRouteScreenState();
}

class _ZoneDetailsRouteScreenState extends State<ZoneDetailsRouteScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  Farm? _farm;
  Zone? _zone;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadZone();
  }

  Future<void> _loadZone() async {
    try {
      final farm = await _firebaseService.getFarmById(widget.farmId);
      final zone = await _firebaseService.getZoneById(
        widget.farmId,
        widget.zoneId,
      );

      setState(() {
        _farm = farm;
        _zone = zone;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _farm = null;
        _zone = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_farm == null || _zone == null) {
      return const Scaffold(
        body: Center(child: Text('Zone not found')),
      );
    }

    return ZoneDetailsScreen(
      farm: _farm!,
      zone: _zone!,
    );
  }
}
