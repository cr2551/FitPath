import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether first-run onboarding has been completed.
///
/// STUB created by #3: always `true`, so the app opens on Home while
/// onboarding is being built. #21 (Complete onboarding) replaces it with the
/// persisted flag from `app_metadata`. The router re-checks its redirect
/// whenever this value changes.
final onboardingCompletedProvider = Provider<bool>((ref) => true);
