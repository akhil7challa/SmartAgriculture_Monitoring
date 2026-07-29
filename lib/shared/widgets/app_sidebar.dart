import 'package:flutter/material.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.green.shade700,
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            "🌿 Smart Farm",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          menuItem(Icons.dashboard, "Dashboard", 0),
          menuItem(Icons.agriculture, "Farms", 1),
          menuItem(Icons.devices, "Devices", 2),
          menuItem(Icons.analytics, "Analytics", 3),
          menuItem(Icons.warning, "Alerts", 4),
          menuItem(Icons.settings, "Settings", 5),
        ],
      ),
    );
  }

  Widget menuItem(IconData icon, String title, int index) {
    final bool isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white,
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        onTap: () {
          onItemSelected(index);
        },
      ),
    );
  }
}
