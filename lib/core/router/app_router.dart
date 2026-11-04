import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// STUB created by #1 so `app.dart` never has to change.
///
/// #3 (App shell and navigation) replaces this file's contents with the full
/// route table and bottom navigation. Keep the `appRouterProvider` name.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _PlaceholderHome()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('FitPath')));
  }
}
