import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_sidebar.dart';

class DashboardLayout extends StatelessWidget {
  final Widget child;

  const DashboardLayout({
    super.key,
    required this.child,
  });

  int _getSelectedPageIndex(BuildContext context) {
    final String location =
        GoRouter.of(context).routeInformationProvider.value.uri.toString();

    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/farms')) return 1;
    if (location.startsWith('/devices')) return 2;
    if (location.startsWith('/analytics')) return 3;
    if (location.startsWith('/alerts')) return 4;
    if (location.startsWith('/settings')) return 5;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedPage = _getSelectedPageIndex(context);

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selectedIndex: selectedPage,
            onItemSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/dashboard');
                  break;
                case 1:
                  context.go('/farms');
                  break;
                case 2:
                  context.go('/devices');
                  break;
                case 3:
                  context.go('/analytics');
                  break;
                case 4:
                  context.go('/alerts');
                  break;
                case 5:
                  context.go('/settings');
                  break;
              }
            },
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
