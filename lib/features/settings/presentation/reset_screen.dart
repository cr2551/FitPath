import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/router/routes.dart';
import '../data/reset_service.dart';
import 'reset_view.dart';

final resetServiceProvider = Provider<ResetService>(
  (ref) => ResetService(ref.watch(appDatabaseProvider)),
);

/// Deletes all user data after a typed confirmation, then opens onboarding.
class ResetScreen extends ConsumerStatefulWidget {
  const ResetScreen({super.key});

  static const confirmWord = 'RESET';

  @override
  ConsumerState<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends ConsumerState<ResetScreen> {
  String _typed = '';
  bool _resetting = false;

  Future<void> _reset() async {
    setState(() => _resetting = true);
    try {
      await ref.read(resetServiceProvider).resetAll();
      if (mounted) context.go(Routes.welcome);
    } on Object {
      if (!mounted) return;
      setState(() => _resetting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't reset. Your data was not changed."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResetView(
      confirmWord: ResetScreen.confirmWord,
      canReset: _typed.trim().toUpperCase() == ResetScreen.confirmWord,
      resetting: _resetting,
      onTyped: (text) => setState(() => _typed = text),
      onBackup: () => context.push(Routes.backup),
      onReset: _reset,
    );
  }
}
