import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../shared/widgets/widgets.dart';
import 'widgets/session_list_tile.dart';

/// The in-progress session, for the resume card.
class ActiveSessionData {
  const ActiveSessionData({
    required this.title,
    required this.summary,
    required this.progress,
  });

  final String title;

  /// "Started 18:05 · 2 exercises · 5 of 9 sets done"
  final String summary;

  /// Completed sets / all sets; null when there are no sets yet.
  final double? progress;
}

class WorkoutsViewData {
  const WorkoutsViewData({required this.active, required this.recent});

  final ActiveSessionData? active;
  final List<SessionTileData> recent;
}

class WorkoutsCallbacks {
  const WorkoutsCallbacks({
    required this.onStart,
    required this.onResume,
    required this.onDiscard,
    required this.onOpenSession,
    required this.onRetry,
  });

  final VoidCallback onStart;
  final VoidCallback onResume;
  final VoidCallback onDiscard;
  final ValueChanged<int> onOpenSession;
  final VoidCallback onRetry;
}

/// Pure layout for the Workouts tab (DESIGN/screens.html, 3).
class WorkoutsView extends StatelessWidget {
  const WorkoutsView({
    super.key,
    required this.data,
    required this.callbacks,
    this.error,
  });

  /// Null while loading.
  final WorkoutsViewData? data;
  final String? error;
  final WorkoutsCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final cb = callbacks;
    const gap = SizedBox(height: AppSpacing.md);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            const ScreenHeader(title: 'Workouts'),
            if (error != null)
              ErrorState(message: error!, onRetry: cb.onRetry)
            else if (d == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (d.active != null) ...[
                _ResumeCard(
                  data: d.active!,
                  onResume: cb.onResume,
                  onDiscard: cb.onDiscard,
                ),
                gap,
                OutlinedButton.icon(
                  onPressed: cb.onStart,
                  icon: const Icon(Icons.add),
                  label: const Text('START NEW WORKOUT'),
                ),
              ] else
                FilledButton.icon(
                  style: AppTheme.accentButton(context),
                  onPressed: cb.onStart,
                  icon: const Icon(Icons.add),
                  label: const Text('START WORKOUT'),
                ),
              gap,
              SectionCard(
                header: const CardHeader(title: 'Recent'),
                child: d.recent.isEmpty
                    ? const EmptyState(
                        message:
                            'No workouts yet. Start one and it shows up here.',
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < d.recent.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            SessionListTile(
                              data: d.recent[i],
                              onTap: () => cb.onOpenSession(d.recent[i].id),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The open session: ink left edge, açaí "live" marker, set progress,
/// Resume and Discard.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.data,
    required this.onResume,
    required this.onDiscard,
  });

  final ActiveSessionData data;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          left: BorderSide(color: c.ink, width: 4),
          top: BorderSide(color: c.line),
          right: BorderSide(color: c.line),
          bottom: BorderSide(color: c.line),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox.square(dimension: 8, child: ColoredBox(color: c.accent)),
              const SizedBox(width: AppSpacing.xs + 2),
              Text('IN PROGRESS', style: t.overline.copyWith(color: c.ink)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(data.title, style: t.cardTitle),
          Text(data.summary, style: t.label),
          const SizedBox(height: AppSpacing.md - 2),
          FitProgressBar(fraction: data.progress, color: c.ink),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('RESUME'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: c.error),
                onPressed: onDiscard,
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks for an optional session name. Returns the name ('' for none), or
/// null when cancelled.
Future<String?> showStartWorkoutDialog(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _StartDialog());

class _StartDialog extends StatefulWidget {
  const _StartDialog();

  @override
  State<_StartDialog> createState() => _StartDialogState();
}

class _StartDialogState extends State<_StartDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Start workout'),
    content: TextField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Name (optional)',
        hintText: 'e.g. Leg day',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_name.text.trim()),
        child: const Text('START'),
      ),
    ],
  );
}
