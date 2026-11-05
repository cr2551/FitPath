import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import 'welcome_view.dart';

/// First onboarding screen: what FitPath does, then Get started.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      WelcomeView(onGetStarted: () => context.push(Routes.setup));
}
