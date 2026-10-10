import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/icons/habit_glyph.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/statistics/widgets/year_heatmap.dart';

/// A card representing a completed focus session with start-end times and duration.
class FocusSessionCard extends StatelessWidget {
  const FocusSessionCard({
    super.key,
    required this.session,
    this.habit,
    this.onDelete,
  });

  final FocusSession session;
  final Habit? habit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final timeFormat = DateFormat.jm(locale);

    final start = session.startedAt;
    final end = session.startedAt.add(Duration(seconds: session.seconds));
    final timeRange = '${timeFormat.format(start)} – ${timeFormat.format(end)}';

    final minutes = (session.seconds / 60).round();
    final durationStr = minutes < 60
        ? '${minutes}m'
        : (minutes % 60 == 0
            ? '${minutes ~/ 60}h'
            : '${minutes ~/ 60}h ${minutes % 60}m');

    final focus = context.watch<FocusController>();
    final sessionTags = session.tags.isNotEmpty
        ? session.tags
        : (session.label.isNotEmpty ? [session.label] : const <String>[]);

    final currentHabit = habit;
    final habitColor = currentHabit?.color ?? scheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: habitColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: habit != null
                ? HabitGlyph(glyph: habit!.icon, size: 18, color: habitColor)
                : Icon(LucideIcons.timer, size: 18, color: habitColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      durationStr,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (sessionTags.isNotEmpty || currentHabit != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (currentHabit != null)
                              _buildPill(currentHabit.name, habitColor),
                            for (final tag in sessionTags)
                              _buildPill(tag, focus.colorForLabel(tag)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      session.completed ? LucideIcons.circleCheck : LucideIcons.flag,
                      size: 13,
                      color: session.completed ? context.tokens.success : context.tokens.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeRange,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: context.tokens.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(
                LucideIcons.trash2,
                size: 15,
                color: context.tokens.muted.withValues(alpha: 0.7),
              ),
              tooltip: context.l10n.delete,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// An annual or rolling activity heatmap of daily focus time.
class FocusActivityMap extends StatelessWidget {
  const FocusActivityMap({
    super.key,
    required this.sessions,
    required this.color,
  });

  final List<FocusSession> sessions;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dailyMinutes = <String, int>{};
    for (final session in sessions) {
      final key = session.countedOn.dayKey;
      final mins = (session.seconds / 60).round();
      dailyMinutes[key] = (dailyMinutes[key] ?? 0) + mins;
    }

    final maxMinutes = dailyMinutes.values.fold<int>(
      60,
      (max, val) => val > max ? val : max,
    );

    return LayoutBuilder(
      builder: (context, box) {
        // Compute a cell size that fills the available width exactly so the
        // heatmap never needs a horizontal scrollbar.
        const cols = 53;
        const gap = 3.0; // matches _gap in year_heatmap.dart
        final cell =
            ((box.maxWidth - (cols - 1) * gap) / cols).clamp(8.0, 14.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YearHeatmap(
              year: AppClock.today().year,
              color: color,
              dailyCounts: dailyMinutes,
              maxCount: maxMinutes,
              cellSize: cell,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Less',
                  style: TextStyle(fontSize: 11, color: context.tokens.muted),
                ),
                const SizedBox(width: 4),
                for (final opacity in [0.2, 0.4, 0.7, 1.0]) ...[
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Text(
                  'More',
                  style: TextStyle(fontSize: 11, color: context.tokens.muted),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Mini metric tile for overview in Details tab.
class FocusMetricCard extends StatelessWidget {
  const FocusMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final color = accent ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
