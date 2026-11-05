import 'package:fitpath/features/profile/domain/goal_rules.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('losing and maintaining weight exclude each other', () {
    expect(
      GoalRules.secondaryOptions(GoalType.loseWeight),
      isNot(contains(GoalType.maintainWeight)),
    );
    expect(
      GoalRules.secondaryOptions(GoalType.maintainWeight),
      isNot(contains(GoalType.loseWeight)),
    );
  });

  test('other goals combine freely, never with themselves', () {
    final options = GoalRules.secondaryOptions(GoalType.buildMuscle);
    expect(options, isNot(contains(GoalType.buildMuscle)));
    expect(options, contains(GoalType.loseWeight));
    expect(options, contains(GoalType.maintainWeight));
    expect(GoalRules.secondaryOptions(null), GoalType.values);
  });
}
