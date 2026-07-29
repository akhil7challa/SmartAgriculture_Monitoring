import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'features/dashboard/dashboard_layout.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/farms/farms_screen.dart';
import 'features/devices/devices_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/alerts/alerts_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/farms/farm_details_route_screen.dart';
import 'features/zones/zone_details_route_screen.dart';
import 'features/devices/device_details_route_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  usePathUrlStrategy();

  runApp(const SmartFarmApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return DashboardLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/farms',
          builder: (context, state) => const FarmsScreen(),
          routes: [
            GoRoute(
              path: ':farmId',
              builder: (context, state) {
                final farmId = state.pathParameters['farmId']!;
                return FarmDetailsRouteScreen(farmId: farmId);
              },
              routes: [
                GoRoute(
                  path: 'zones/:zoneId',
                  builder: (context, state) {
                    final farmId = state.pathParameters['farmId']!;
                    final zoneId = state.pathParameters['zoneId']!;
                    return ZoneDetailsRouteScreen(
                      farmId: farmId,
                      zoneId: zoneId,
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'devices/:deviceId',
                      builder: (context, state) {
                        final farmId = state.pathParameters['farmId']!;
                        final zoneId = state.pathParameters['zoneId']!;
                        final deviceId = state.pathParameters['deviceId']!;

                        return DeviceDetailsRouteScreen(
                          farmId: farmId,
                          zoneId: zoneId,
                          deviceId: deviceId,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/devices',
          builder: (context, state) => const DevicesScreen(),
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/alerts',
          builder: (context, state) => const AlertsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

class SmartFarmApp extends StatelessWidget {
  const SmartFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      routerConfig: _router,
    );
  }
}
