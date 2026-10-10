import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/express/express_shapes.dart';
import 'package:streak/core/express/express_type.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/icons/habit_glyph.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';
import 'package:streak/features/statistics/widgets/year_heatmap.dart';

/// Stylized hero card showing today's focus hours, goal progress, active session indicator,
/// and the primary "Start Session" button.
class FocusTodayHero extends StatelessWidget {
  const FocusTodayHero({
    super.key,
    required this.todaySeconds,
    required this.sessionCount,
    required this.dailyGoalMinutes,
    required this.onStartSession,
  });

  final int todaySeconds;
  final int sessionCount;
  final int dailyGoalMinutes;
  final VoidCallback onStartSession;

  String _formatHours(int seconds) {
    if (seconds <= 0) return '0m';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusController>();
    final settings = context.watch<SettingsController>();
    final express = settings.isExpressStyle;
    final minimal = settings.isMinimalStyle;
    final scheme = context.colors;
    final accent = scheme.primary;
    final isActive = focus.isActive;

    final goalSeconds = dailyGoalMinutes * 60;
    final goalRatio = goalSeconds > 0
        ? (todaySeconds / goalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final goalPercent = (goalRatio * 100).round();

    final timeString = _formatHours(todaySeconds);

    return Container(
      decoration: express
          ? ShapeDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              shape: const ExpressBorder(shape: ExpressShape.cookie),
            )
          : BoxDecoration(
              color: minimal
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.today.toUpperCase(),
                      style: express
                          ? ExpressType.body.at(
                              11.5,
                              weight: 800,
                              color: context.tokens.muted,
                            )
                          : TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: context.tokens.muted,
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeString,
                      style: statNumber(context, 44, color: accent),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.flame,
                          size: 14,
                          color: context.tokens.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sessionCount == 1
                              ? '1 session completed'
                              : '$sessionCount sessions completed',
                          style: statLabel(context).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (dailyGoalMinutes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$goalPercent%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'of ${dailyGoalMinutes}m goal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (dailyGoalMinutes > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: goalRatio,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
          if (isActive) ...[
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onStartSession,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: focus.isRunning ? context.tokens.success : context.tokens.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        focus.isRunning
                            ? 'Session in progress (${formatDuration(focus.displaySeconds)})'
                            : 'Session paused (${formatDuration(focus.displaySeconds)})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 16, color: accent),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onStartSession,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: accent.computeLuminance() > 0.6 ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Icon(
              isActive ? LucideIcons.timerReset : LucideIcons.play,
              size: 18,
            ),
            label: Text(
              isActive ? 'Resume Active Session' : context.l10n.focus_start,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

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

    final habitColor = habit?.color ?? scheme.primary;
    final title = habit != null ? '$durationStr - ${habit.name}' : durationStr;

    final focus = context.watch<FocusController>();
    final sessionTags = session.tags.isNotEmpty
        ? session.tags
        : (session.label.isNotEmpty ? [session.label] : const <String>[]);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
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
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sessionTags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final tag in sessionTags)
                        Builder(
                          builder: (context) {
                            final tagColor = focus.colorForLabel(tag);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: tagColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: tagColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: tagColor,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
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
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                durationStr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: habitColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                session.completed ? LucideIcons.circleCheck : LucideIcons.flag,
                size: 14,
                color: session.completed ? context.tokens.success : context.tokens.muted,
              ),
            ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YearHeatmap(
          year: AppClock.today().year,
          color: color,
          dailyCounts: dailyMinutes,
          maxCount: maxMinutes,
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
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
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
