import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../models/device.dart';
import '../../models/farm.dart';
import '../../models/zone.dart';
import 'device_details_screen.dart';

class DeviceDetailsRouteScreen extends StatefulWidget {
  final String farmId;
  final String zoneId;
  final String deviceId;

  const DeviceDetailsRouteScreen({
    super.key,
    required this.farmId,
    required this.zoneId,
    required this.deviceId,
  });

  @override
  State<DeviceDetailsRouteScreen> createState() =>
      _DeviceDetailsRouteScreenState();
}

class _DeviceDetailsRouteScreenState extends State<DeviceDetailsRouteScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  Farm? _farm;
  Zone? _zone;
  Device? _device;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final farm = await _firebaseService.getFarmById(widget.farmId);
      final zone = await _firebaseService.getZoneById(
        widget.farmId,
        widget.zoneId,
      );
      final device = await _firebaseService.getDeviceById(widget.deviceId);

      if (farm == null ||
          zone == null ||
          device == null ||
          device.farmId != widget.farmId ||
          device.zoneId != widget.zoneId) {
        setState(() {
          _farm = null;
          _zone = null;
          _device = null;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _farm = farm;
        _zone = zone;
        _device = device;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _farm = null;
        _zone = null;
        _device = null;
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

    if (_device == null) {
      return const Scaffold(
        body: Center(child: Text('Device not found')),
      );
    }

    return DeviceDetailsScreen(device: _device!);
  }
}
