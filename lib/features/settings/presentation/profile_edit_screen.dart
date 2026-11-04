import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../profile/application/profile_providers.dart';
import 'profile_edit_view.dart';

/// Edits the single local profile. Height is entered in the display unit
/// (cm or inches) and always stored in cm. Only the profile row changes;
/// weight entries, diary and workouts are never touched.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  bool _initialized = false;
  double? _age;
  double? _heightCm;
  Sex _sex = Sex.unspecified;
  ActivityLevel? _activity;
  TrainingExperience? _experience;
  int? _frequency;
  bool _saving = false;

  void _init(UserProfileRow? p) {
    _initialized = true;
    _age = p?.ageYears?.toDouble();
    _heightCm = p?.heightCm;
    _sex = p?.sex ?? Sex.unspecified;
    _activity = p?.activityLevel;
    _experience = p?.trainingExperience;
    _frequency = p?.trainingFrequencyPerWeek;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveProfile(
            ageYears: _age?.round(),
            heightCm: _heightCm,
            sex: _sex,
            activityLevel: _activity,
            trainingExperience: _experience,
            trainingFrequencyPerWeek: _frequency,
          );
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go(Routes.profile);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save your details.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final units = ref.watch(unitSystemProvider);

    ProfileEditViewData? data;
    String? error;
    if (profile.hasError || units.hasError) {
      error = "Couldn't load your details.";
    } else if (profile.hasValue && units.hasValue) {
      if (!_initialized) _init(profile.requireValue);
      final imperial = units.requireValue == UnitSystem.imperial;
      const cm = PlausibleRanges.heightCm;
      data = ProfileEditViewData(
        ageYears: _age,
        height: _heightCm == null
            ? null
            : imperial
            ? Units.cmToInches(_heightCm!)
            : _heightCm,
        heightUnit: imperial ? 'in' : 'cm',
        heightRange: imperial
            ? ValueRange(
                (Units.cmToInches(cm.min) * 10).ceil() / 10,
                (Units.cmToInches(cm.max) * 10).floor() / 10,
              )
            : cm,
        sex: _sex,
        activity: _activity,
        experience: _experience,
        frequency: _frequency,
        // Age and height drive every estimate, so both are required.
        canSave: _age != null && _heightCm != null,
        saving: _saving,
      );

      return ProfileEditView(
        data: data,
        callbacks: ProfileEditCallbacks(
          onAge: (v) => setState(() => _age = v),
          onHeight: (v) => setState(
            () => _heightCm = v == null
                ? null
                : imperial
                ? Units.inchesToCm(v)
                : v,
          ),
          onSex: (v) => setState(() => _sex = v),
          onActivity: (v) => setState(() => _activity = v),
          onExperience: (v) => setState(() => _experience = v),
          onFrequency: (v) => setState(() => _frequency = v),
          onSave: _save,
          onRetry: () => ref.invalidate(profileProvider),
        ),
      );
    }

    return ProfileEditView(
      data: null,
      error: error,
      callbacks: ProfileEditCallbacks(
        onAge: (_) {},
        onHeight: (_) {},
        onSex: (_) {},
        onActivity: (_) {},
        onExperience: (_) {},
        onFrequency: (_) {},
        onSave: () {},
        onRetry: () => ref.invalidate(profileProvider),
      ),
    );
  }
}
