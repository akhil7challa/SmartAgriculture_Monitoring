import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../models/farm.dart';
import 'farm_details_screen.dart';

class FarmDetailsRouteScreen extends StatefulWidget {
  final String farmId;

  const FarmDetailsRouteScreen({
    super.key,
    required this.farmId,
  });

  @override
  State<FarmDetailsRouteScreen> createState() => _FarmDetailsRouteScreenState();
}

class _FarmDetailsRouteScreenState extends State<FarmDetailsRouteScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  Farm? _farm;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarm();
  }

  Future<void> _loadFarm() async {
    final farms = await _firebaseService.getAllFarms();
    final farm = farms.firstWhere(
      (item) => item.id == widget.farmId,
      orElse: () => throw Exception('Farm not found'),
    );

    setState(() {
      _farm = farm;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_farm == null) {
      return const Scaffold(
        body: Center(child: Text('Farm not found')),
      );
    }

    return FarmDetailsScreen(farm: _farm!);
  }
}
