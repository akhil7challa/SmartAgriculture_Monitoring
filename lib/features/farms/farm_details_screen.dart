import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/firebase_service.dart';
import '../../models/farm.dart';
import '../../models/zone.dart';

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

  static const Color _bg = Color(0xFF0B1220);
  static const Color _card = Color(0xFF111827);
  static const Color _border = Color(0xFF243041);
  static const Color _textPrimary = Color(0xFFF9FAFB);
  static const Color _textSecondary = Color(0xFF9CA3AF);
  static const Color _accentBlue = Color(0xFF60A5FA);

  @override
  void initState() {
    super.initState();
    _loadFarmData();
  }

  Future<void> _loadFarmData() async {
    try {
      final zones = await _firebaseService.getZones(widget.farm.id);

      if (!mounted) return;

      setState(() {
        _zones = zones;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Farm details load error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildZoneCard(Zone zone) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.go('/farms/${widget.farm.id}/zones/${zone.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _accentBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    size: 28,
                    color: _accentBlue,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  zone.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Zone ID: ${zone.id}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _textSecondary,
          ),
          SizedBox(width: 10),
          Text(
            "No zones found",
            style: TextStyle(
              color: _textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _accentBlue,
        ),
      );
    }

    return Container(
      color: _bg,
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text(
            widget.farm.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.farm.location,
            style: const TextStyle(
              fontSize: 15,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Zones",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_zones.isEmpty)
            _buildEmptyState()
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.8,
                  ),
                  itemBuilder: (context, index) {
                    final zone = _zones[index];
                    return _buildZoneCard(zone);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
