import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

/// One card in the edit list.
class EditCardRowData {
  const EditCardRowData({
    required this.id,
    required this.title,
    required this.description,
    required this.visible,
  });

  final int id;
  final String title;
  final String description;
  final bool visible;
}

class DashboardEditCallbacks {
  const DashboardEditCallbacks({
    required this.onReorder,
    required this.onToggleVisible,
    required this.onRemove,
    required this.onAdd,
    required this.onRestorePreset,
  });

  /// Every card id in the new order.
  final ValueChanged<List<int>> onReorder;
  final void Function(int id, bool visible) onToggleVisible;
  final ValueChanged<int> onRemove;

  /// Null when every card type is already on the dashboard.
  final VoidCallback? onAdd;
  final VoidCallback onRestorePreset;
}

/// Edit mode for Home: drag to reorder, show/hide, remove, add.
///
/// Keeps a local copy of the order so a drag lands immediately, before the
/// saved layout streams back.
class DashboardEditView extends StatefulWidget {
  const DashboardEditView({
    super.key,
    required this.header,
    required this.rows,
    required this.callbacks,
  });

  final Widget header;
  final List<EditCardRowData> rows;
  final DashboardEditCallbacks callbacks;

  @override
  State<DashboardEditView> createState() => _DashboardEditViewState();
}

class _DashboardEditViewState extends State<DashboardEditView> {
  late List<EditCardRowData> _rows = widget.rows;

  @override
  void didUpdateWidget(DashboardEditView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows != widget.rows) _rows = widget.rows;
  }

  void _reorder(int from, int to) {
    final rows = [..._rows];
    rows.insert(to, rows.removeAt(from));
    setState(() => _rows = rows);
    widget.callbacks.onReorder([for (final r in rows) r.id]);
  }

  @override
  Widget build(BuildContext context) {
    final cb = widget.callbacks;
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      buildDefaultDragHandles: false,
      header: widget.header,
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_rows.isEmpty)
              const EmptyState(message: 'No cards on your dashboard.'),
            OutlinedButton.icon(
              onPressed: cb.onAdd,
              icon: const Icon(Icons.add),
              label: const Text('ADD CARDS'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: cb.onRestorePreset,
              child: const Text('Restore suggested layout'),
            ),
          ],
        ),
      ),
      itemCount: _rows.length,
      onReorderItem: _reorder,
      itemBuilder: (context, i) => Padding(
        key: ValueKey(_rows[i].id),
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _EditRow(
          index: i,
          row: _rows[i],
          onToggleVisible: () =>
              cb.onToggleVisible(_rows[i].id, !_rows[i].visible),
          onRemove: () => cb.onRemove(_rows[i].id),
        ),
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.index,
    required this.row,
    required this.onToggleVisible,
    required this.onRemove,
  });

  final int index;
  final EditCardRowData row;
  final VoidCallback onToggleVisible;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: 'Drag to reorder ${row.title}',
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Icon(Icons.drag_indicator, color: c.inkMuted),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: t.bodyStrong.copyWith(
                      color: row.visible ? c.ink : c.inkMuted,
                    ),
                  ),
                  Text(
                    row.visible ? row.description : 'Hidden',
                    style: t.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: row.visible ? 'Hide ${row.title}' : 'Show ${row.title}',
              onPressed: onToggleVisible,
              icon: Icon(
                row.visible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Remove ${row.title}',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
