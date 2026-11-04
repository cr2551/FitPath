import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(appDatabaseProvider).dashboardDao),
);

/// Every dashboard card (visible and hidden) in display order.
final dashboardLayoutProvider = StreamProvider<List<DashboardCard>>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchLayout(),
);
