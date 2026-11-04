import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/fit_colors.dart';

/// One muted line plus one action, for screens and cards with no data yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(message, style: context.textStyles.label)),
          if (actionLabel != null && onAction != null)
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 16),
              label: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// A clear, non-blocking error with an optional retry.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: c.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.textStyles.label.copyWith(color: c.ink),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading and error states. For use
/// in containers (the layer that reads providers), not in pure views.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.errorMessage = 'Something went wrong.',
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value) => data(value),
      AsyncError() => ErrorState(message: errorMessage, onRetry: onRetry),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// Asks the user to confirm an action. Returns true only if they confirm.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final c = context.fitColors;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: c.error,
                  foregroundColor: c.surface,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel.toUpperCase()),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// The square "ESTIMATE" label. Tapping it should explain the inputs.
class EstimateBadge extends StatelessWidget {
  const EstimateBadge({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    return Semantics(
      button: onTap != null,
      label: 'Estimate. Tap for how it is calculated.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: c.inkMuted),
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Text(
              'ESTIMATE',
              style: context.textStyles.overline.copyWith(fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet explaining how an estimate was calculated.
Future<void> showEstimateSheet(
  BuildContext context, {
  required String title,
  required String explanation,
  List<String> notes = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    builder: (context) {
      final t = context.textStyles;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.cardTitle),
              const SizedBox(height: AppSpacing.sm),
              Text(explanation, style: t.body),
              for (final note in notes) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(note, style: t.label),
              ],
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: AppTheme.accentButton(context),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('GOT IT'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
