import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_providers.dart';

final _onboardingFlagProvider = StreamProvider<bool>(
  (ref) => ref.watch(profileRepositoryProvider).watchOnboardingCompleted(),
);

/// Whether first-run onboarding has been completed, from
/// `app_metadata.onboarding_completed`. Null until the flag has loaded.
///
/// The router redirects to onboarding while this is false and re-checks
/// its redirect whenever it changes (completing onboarding, or a reset).
final onboardingCompletedProvider = Provider<bool?>(
  (ref) => ref.watch(_onboardingFlagProvider).value,
);
