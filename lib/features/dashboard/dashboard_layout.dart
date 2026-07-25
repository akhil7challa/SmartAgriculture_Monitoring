import 'package:flutter/material.dart';

import '../../shared/widgets/app_sidebar.dart';

import 'dashboard_screen.dart';

import '../farms/farms_screen.dart';

import '../devices/devices_screen.dart';

import '../analytics/analytics_screen.dart';

import '../alerts/alerts_screen.dart';

import '../settings/settings_screen.dart';

class DashboardLayout extends StatefulWidget {
  const DashboardLayout({super.key});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  int selectedPage = 0;

  final pages = const [
    DashboardScreen(),

    FarmsScreen(),

    DevicesScreen(),

    AnalyticsScreen(),

    AlertsScreen(),

    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            onItemSelected: (index) {
              setState(() {
                selectedPage = index;
              });
            },
          ),

          Expanded(child: pages[selectedPage]),
        ],
      ),
    );
  }
}
