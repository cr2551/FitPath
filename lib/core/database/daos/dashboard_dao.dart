import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/app_tables.dart';

part 'dashboard_dao.g.dart';

/// Dashboard layout queries. Owned by #17 (Dashboard layout repository).
@DriftAccessor(tables: [DashboardCards])
class DashboardDao extends DatabaseAccessor<AppDatabase>
    with _$DashboardDaoMixin {
  DashboardDao(super.attachedDatabase);
}
