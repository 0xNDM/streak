import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/app_confirm_dialog.dart';
import 'package:streak/features/focus/data/focus_label.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_widgets.dart';
import 'package:streak/features/focus/widgets/focus_label_picker.dart';
import 'package:streak/features/focus/widgets/focus_period_navigator.dart';
import 'package:streak/features/focus/widgets/focus_session_edit_dialog.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';

class FocusLabelsView extends StatefulWidget {
  const FocusLabelsView({
    super.key,
    required this.focus,
    this.weekStart = 1,
    required this.accent,
  });

  final FocusController focus;
  final int weekStart;
  final Color accent;

  @override
  State<FocusLabelsView> createState() => _FocusLabelsViewState();
}

class _FocusLabelsViewState extends State<FocusLabelsView> {
  int _periodIndex = 0; // 0 = Week, 1 = Month, 2 = All Time
  int _offset = 0;
  bool _archivedExpanded = false;

  Future<void> _deletePermanently(BuildContext context, FocusLabel label) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.focus_label_delete,
      message: context.l10n.focus_label_delete_body(
        widget.focus.labelDisplayName(label.id),
      ),
      confirmLabel: context.l10n.delete,
    );
    if (confirmed == true && mounted) {
      await widget.focus.deleteLabelPermanently(label.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = AppClock.now();
    final focus = widget.focus;
    final habits = context.watch<HabitsController>();

    final period = _periodIndex == 0
        ? 'week'
        : (_periodIndex == 1 ? 'month' : 'all');
    final analysis = focus.labelAnalysisForPeriod(
      period,
      widget.weekStart,
      offset: _offset,
      now: now,
    );

    final periodLabel = _periodIndex == 0
        ? formatWeekPeriod(context, _offset, widget.weekStart, now: now)
        : (_periodIndex == 1
            ? formatMonthPeriod(context, _offset, now: now)
            : context.l10n.period_all_time);

    final activeLabels = focus.labels;
    final parents = activeLabels.where((l) => !l.isChild).toList();
    final parentIds = parents.map((l) => l.id).toSet();
    final orphanChildren = activeLabels
        .where((l) => l.isChild && !parentIds.contains(l.parentId))
        .toList();
    final archived = focus.archivedLabels;
    final recentEditable = focus.recentEditableSessions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header Card with Title and Actions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final titleArea = Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.tags,
                          color: widget.accent,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.focus_labels,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FocusPeriodNavigator(
                              label: periodLabel,
                              offset: _offset,
                              showArrows: _periodIndex != 2,
                              onOffsetChanged: (val) =>
                                  setState(() => _offset = val),
                              accent: widget.accent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final controls = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Segmented(
                        options: [
                          context.l10n.week,
                          context.l10n.month,
                          context.l10n.period_all_time,
                        ],
                        index: _periodIndex,
                        onChanged: (i) => setState(() {
                          _periodIndex = i;
                          _offset = 0;
                        }),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => showCreateOrEditLabelDialog(context),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(context.l10n.focus_label_new),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.accent,
                          foregroundColor: Colors.black,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 650) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleArea,
                        const SizedBox(height: 14),
                        controls,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: titleArea),
                      const SizedBox(width: 16),
                      controls,
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // Summary metric strip
              Row(
                children: [
                  _SummaryStat(
                    label: context.l10n.focus_focus_time,
                    value: formatHoursShort(analysis.totalPeriodSeconds),
                    icon: LucideIcons.timer,
                    accent: widget.accent,
                  ),
                  const SizedBox(width: 16),
                  _SummaryStat(
                    label: context.l10n.focus_label,
                    value: '${activeLabels.length}',
                    icon: LucideIcons.tag,
                  ),
                  const SizedBox(width: 16),
                  _SummaryStat(
                    label: context.l10n.focus_todays_sessions,
                    value: '${analysis.totalSessions}',
                    icon: LucideIcons.circleCheck,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Hierarchical Labels List with Analysis
        if (parents.isEmpty && orphanChildren.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.tags, size: 36, color: context.tokens.muted),
                const SizedBox(height: 12),
                Text(
                  context.l10n.focus_no_tag_data,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.muted,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => showCreateOrEditLabelDialog(context),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: Text(context.l10n.focus_label_new),
                ),
              ],
            ),
          )
        else ...[
          for (final parent in parents)
            _ParentLabelCard(
              parent: parent,
              focus: focus,
              children: focus.childrenOf(parent.id),
              secondsByLabel: analysis.secondsByLabel,
              totalPeriodSeconds: analysis.totalPeriodSeconds,
              onEdit: () =>
                  showCreateOrEditLabelDialog(context, labelToEdit: parent),
              onAddSubLabel: () => showCreateOrEditLabelDialog(
                context,
                preselectedParentId: parent.id,
              ),
              onArchive: () => focus.archiveLabel(parent.id),
              onDelete: () => _deletePermanently(context, parent),
              onEditChild: (child) =>
                  showCreateOrEditLabelDialog(context, labelToEdit: child),
              onArchiveChild: (child) => focus.archiveLabel(child.id),
              onDeleteChild: (child) => _deletePermanently(context, child),
            ),
          for (final orphan in orphanChildren)
            _ParentLabelCard(
              parent: orphan,
              focus: focus,
              children: const [],
              secondsByLabel: analysis.secondsByLabel,
              totalPeriodSeconds: analysis.totalPeriodSeconds,
              onEdit: () =>
                  showCreateOrEditLabelDialog(context, labelToEdit: orphan),
              onAddSubLabel: () => showCreateOrEditLabelDialog(
                context,
                preselectedParentId: orphan.id,
              ),
              onArchive: () => focus.archiveLabel(orphan.id),
              onDelete: () => _deletePermanently(context, orphan),
              onEditChild: (_) {},
              onArchiveChild: (_) {},
              onDeleteChild: (_) {},
            ),
        ],

        // 3. Archived Labels Section
        if (archived.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _archivedExpanded,
                onExpansionChanged: (v) => setState(() => _archivedExpanded = v),
                leading: Icon(
                  LucideIcons.archive,
                  size: 18,
                  color: context.tokens.muted,
                ),
                title: Text(
                  '${context.l10n.focus_archived_labels} (${archived.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.muted,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      children: [
                        for (final item in archived)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              focus.labelDisplayName(item.id),
                              style: TextStyle(
                                fontSize: 13.5,
                                color: context.tokens.muted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () => focus.unarchiveLabel(item.id),
                                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                                  label: Text(context.l10n.undo),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.trash2,
                                    size: 15,
                                    color: context.tokens.danger,
                                  ),
                                  tooltip: context.l10n.delete,
                                  onPressed: () =>
                                      _deletePermanently(context, item),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // 4. Recent Finished Sessions (Editable within first 12h)
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.clock,
                          color: Color(0xFF3B82F6),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.focus_recent_sessions_editable,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            context.l10n.focus_editable_12h_hint,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.tokens.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (recentEditable.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${recentEditable.length}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (recentEditable.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      context.l10n.focus_no_editable_sessions,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.muted,
                      ),
                    ),
                  ),
                )
              else
                for (final session in recentEditable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FocusSessionCard(
                      session: session,
                      habit: session.habitId.isEmpty
                          ? null
                          : habits.byId(session.habitId),
                      onEdit: () => editFocusSession(context, session),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tint = accent ?? scheme.onSurface;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.tokens.muted,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: tint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentLabelCard extends StatefulWidget {
  const _ParentLabelCard({
    required this.parent,
    required this.focus,
    required this.children,
    required this.secondsByLabel,
    required this.totalPeriodSeconds,
    required this.onEdit,
    required this.onAddSubLabel,
    required this.onArchive,
    required this.onDelete,
    required this.onEditChild,
    required this.onArchiveChild,
    required this.onDeleteChild,
  });

  final FocusLabel parent;
  final FocusController focus;
  final List<FocusLabel> children;
  final Map<String, int> secondsByLabel;
  final int totalPeriodSeconds;
  final VoidCallback onEdit;
  final VoidCallback onAddSubLabel;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final ValueChanged<FocusLabel> onEditChild;
  final ValueChanged<FocusLabel> onArchiveChild;
  final ValueChanged<FocusLabel> onDeleteChild;

  @override
  State<_ParentLabelCard> createState() => _ParentLabelCardState();
}

class _ParentLabelCardState extends State<_ParentLabelCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final parent = widget.parent;
    final children = widget.children;

    // Aggregate seconds: parent's own seconds + all its children's seconds
    var parentTotalSec = widget.secondsByLabel[parent.id] ?? 0;
    for (final child in children) {
      parentTotalSec += (widget.secondsByLabel[child.id] ?? 0);
    }

    final sharePct = widget.totalPeriodSeconds > 0
        ? (parentTotalSec / widget.totalPeriodSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: parent.color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Parent Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                // Color circle indicator
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: parent.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: parent.color.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          parent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (children.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: parent.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${children.length} sub',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: parent.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Period Duration
                Text(
                  formatHoursShort(parentTotalSec),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: parent.color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(sharePct * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.muted,
                  ),
                ),
                const SizedBox(width: 8),
                // Action Buttons
                IconButton(
                  icon: const Icon(LucideIcons.plus, size: 16),
                  tooltip: context.l10n.focus_add_sub_label,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onAddSubLabel,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.pencil, size: 14),
                  tooltip: context.l10n.edit,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onEdit,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.archive, size: 14),
                  tooltip: context.l10n.focus_label_archive,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onArchive,
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.trash2,
                    size: 14,
                    color: context.tokens.danger,
                  ),
                  tooltip: context.l10n.delete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onDelete,
                ),
                if (children.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      _expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
              ],
            ),
          ),

          // Percentage Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 4,
                width: double.infinity,
                color: scheme.surfaceContainerHighest,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: sharePct,
                  child: Container(color: parent.color),
                ),
              ),
            ),
          ),

          // Children Sub-labels List
          if (children.isNotEmpty && _expanded) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 16, 10),
              child: Column(
                children: [
                  for (final child in children) ...[
                    Builder(
                      builder: (context) {
                        final childSec =
                            widget.secondsByLabel[child.id] ?? 0;
                        final childShare = parentTotalSec > 0
                            ? (childSec / parentTotalSec).clamp(0.0, 1.0)
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.cornerDownRight,
                                size: 14,
                                color: parent.color.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: child.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  child.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                formatHoursShort(childSec),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: child.color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${(childShare * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.tokens.muted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(LucideIcons.pencil, size: 13),
                                tooltip: context.l10n.edit,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                onPressed: () => widget.onEditChild(child),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.archive, size: 13),
                                tooltip: context.l10n.focus_label_archive,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                onPressed: () => widget.onArchiveChild(child),
                              ),
                              IconButton(
                                icon: Icon(
                                  LucideIcons.trash2,
                                  size: 13,
                                  color: context.tokens.danger,
                                ),
                                tooltip: context.l10n.delete,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                onPressed: () => widget.onDeleteChild(child),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}
