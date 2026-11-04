import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The persistent bottom navigation around the five main destinations.
///
/// Pure layout: it only knows the shell's current index and how to switch
/// branches. Styling comes from the theme's `NavigationBarTheme` (#2).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.restaurant_outlined),
      selectedIcon: Icon(Icons.restaurant),
      label: 'Nutrition',
    ),
    NavigationDestination(
      icon: Icon(Icons.fitness_center_outlined),
      selectedIcon: Icon(Icons.fitness_center),
      label: 'Workouts',
    ),
    NavigationDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: 'Progress',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  void _select(int index) => navigationShell.goBranch(
    index,
    // Tapping the active tab again returns to its first screen.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final onHome = navigationShell.currentIndex == 0;
    return PopScope(
      // System back on another tab's first screen goes to Home instead of
      // closing the app.
      canPop: onHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _select,
          destinations: _destinations,
        ),
      ),
    );
  }
}
