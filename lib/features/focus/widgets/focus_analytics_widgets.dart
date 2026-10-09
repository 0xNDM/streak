import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/date_labels.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/icons/habit_glyph.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/data/focus_stats.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_widgets.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';

class WeeklyFocusComparisonCard extends StatelessWidget {
  const WeeklyFocusComparisonCard({
    super.key,
    required this.stats,
    required this.targetHours,
    required this.accent,
  });

  final FocusStats stats;
  final int targetHours;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final weekHours = stats.weekSeconds / 3600;
    final target = targetHours <= 0 ? 10.0 : targetHours.toDouble();
    final progress = (weekHours / target).clamp(0.0, 1.0);
    final remainingHours = (target - weekHours).clamp(0.0, target);
    final isReached = weekHours >= target;
    final change = stats.weeklyChangePercent;
    final isUp = change >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Focus Target',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.tokens.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        formatHoursShort(stats.weekSeconds),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        ' / ${target.toInt()}h',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isUp ? context.tokens.success : context.tokens.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                      size: 15,
                      color: isUp ? context.tokens.success : context.tokens.warning,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${isUp ? '+' : ''}${change.toStringAsFixed(0)}% vs last week',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isUp ? context.tokens.success : context.tokens.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% of weekly target',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.muted,
                ),
              ),
              Text(
                isReached
                    ? 'Target reached! 🎉'
                    : '${remainingHours.toStringAsFixed(1)}h to go',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isReached ? context.tokens.success : context.tokens.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FocusKpiGrid extends StatelessWidget {
  const FocusKpiGrid({
    super.key,
    required this.stats,
    required this.accent,
  });

  final FocusStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final bestDayLabel = stats.longestDayDate == null
        ? ''
        : ' (${dateFormat.format(stats.longestDayDate!)})';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FocusMetricCard(
                title: context.l10n.today,
                value: formatHoursShort(stats.todaySeconds),
                icon: LucideIcons.sun,
                accent: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FocusMetricCard(
                title: context.l10n.week,
                value: formatHoursShort(stats.weekSeconds),
                icon: LucideIcons.calendarDays,
                accent: context.tokens.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FocusMetricCard(
                title: 'Longest Session',
                value: formatHoursShort(stats.longestSessionSeconds),
                icon: LucideIcons.timer,
                accent: context.tokens.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FocusMetricCard(
                title: 'Best Focus Day',
                value: '${formatHoursShort(stats.longestDaySeconds)}$bestDayLabel',
                icon: LucideIcons.trophy,
                accent: context.tokens.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FocusMetricCard(
                title: 'Current Streak',
                value: '${stats.currentStreak} ${context.l10n.days}',
                icon: LucideIcons.flame,
                accent: const Color(0xFFF97316),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FocusMetricCard(
                title: 'Longest Streak',
                value: '${stats.longestStreak} ${context.l10n.days}',
                icon: LucideIcons.sparkles,
                accent: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WeeklyContinuousTimeline extends StatefulWidget {
  const WeeklyContinuousTimeline({
    super.key,
    required this.sessions,
    required this.accent,
  });

  final List<FocusSession> sessions;
  final Color accent;

  @override
  State<WeeklyContinuousTimeline> createState() => _WeeklyContinuousTimelineState();
}

class _WeeklyContinuousTimelineState extends State<WeeklyContinuousTimeline> {
  int _weekOffset = 0;

  DateTime get _now => AppClock.now();

  DateTime get _weekStart {
    final today = _now.subtract(Duration(hours: AppClock.cutoffHour)).atMidnight;
    final monday = today.subtract(Duration(days: (today.weekday - 1) % 7));
    return monday.add(Duration(days: _weekOffset * 7));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final focus = context.watch<FocusController>();
    final habits = context.watch<HabitsController>();
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    final formatRange = DateFormat('MMM d');
    final rangeText = '${formatRange.format(start)} – ${formatRange.format(end)}, ${start.year}';

    // Group sessions by day of week
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final sessionsByDay = <int, List<FocusSession>>{};
    var weekTotalSeconds = 0;

    for (var i = 0; i < 7; i++) {
      final dayKey = days[i].dayKey;
      final daySessions = widget.sessions
          .where((s) => s.countedOn.dayKey == dayKey)
          .toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      sessionsByDay[i] = daySessions;
      for (final s in daySessions) {
        weekTotalSeconds += s.seconds;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Focus Timeline',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rangeText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.tokens.muted,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Total: ${formatHoursShort(weekTotalSeconds)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: widget.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _weekOffset--),
                  ),
                  if (_weekOffset != 0)
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _weekOffset = 0),
                      child: const Text('Today', style: TextStyle(fontSize: 12)),
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.chevronRight, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: _weekOffset >= 0 ? null : () => setState(() => _weekOffset++),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Time ruler
          Row(
            children: [
              const SizedBox(width: 58), // Width of day label
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('00:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('04:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('08:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('12:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('16:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('20:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('24:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 52), // Width of right badge
            ],
          ),
          const SizedBox(height: 8),
          // 7 Daily Tracks
          for (var i = 0; i < 7; i++) ...[
            _DailyTrackRow(
              date: days[i],
              sessions: sessionsByDay[i] ?? const [],
              focus: focus,
              habits: habits,
              defaultAccent: widget.accent,
            ),
            if (i < 6) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DailyTrackRow extends StatelessWidget {
  const _DailyTrackRow({
    required this.date,
    required this.sessions,
    required this.focus,
    required this.habits,
    required this.defaultAccent,
  });

  final DateTime date;
  final List<FocusSession> sessions;
  final FocusController focus;
  final HabitsController habits;
  final Color defaultAccent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final dayLabelFormat = DateFormat('E d');
    final label = dayLabelFormat.format(date);
    final isToday = date.dayKey == AppClock.now().dayKey;
    final daySeconds = sessions.fold<int>(0, (sum, s) => sum + s.seconds);

    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday ? defaultAccent : context.tokens.muted,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final totalWidth = box.maxWidth;
              return Container(
                height: 24,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Stack(
                  children: [
                    for (final session in sessions)
                      _buildSessionPill(context, session, totalWidth),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            daySeconds > 0 ? formatHoursShort(daySeconds) : '—',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: daySeconds > 0 ? scheme.onSurface : context.tokens.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionPill(
    BuildContext context,
    FocusSession session,
    double totalWidth,
  ) {
    final start = session.startedAt;
    final startMinutes = start.hour * 60 + start.minute;
    final durationMinutes = (session.seconds / 60).clamp(1.0, 1440.0);

    final leftPos = (startMinutes / 1440.0) * totalWidth;
    final pillWidth = ((durationMinutes / 1440.0) * totalWidth).clamp(4.0, totalWidth);

    final habit = habits.byId(session.habitId);
    final firstTag = session.tags.isNotEmpty ? session.tags.first : session.label;
    final tagColor = firstTag.isNotEmpty ? focus.colorForLabel(firstTag) : null;
    final color = tagColor ?? habit?.color ?? defaultAccent;

    final timeFormat = DateFormat('HH:mm');
    final endTime = start.add(Duration(seconds: session.seconds));
    final timeStr = '${timeFormat.format(start)} – ${timeFormat.format(endTime)}';
    final habitTitle = habit?.name ?? 'Focus Session';
    final tagsStr = session.tags.isNotEmpty ? ' [${session.tags.join(', ')}]' : '';
    final tooltipText = '$habitTitle$tagsStr\n$timeStr (${formatHoursShort(session.seconds)})';

    return Positioned(
      left: leftPos.clamp(0.0, totalWidth - pillWidth),
      width: pillWidth,
      top: 2,
      bottom: 2,
      child: Tooltip(
        message: tooltipText,
        preferBelow: false,
        decoration: BoxDecoration(
          color: context.colors.inverseSurface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: context.colors.onInverseSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(pillWidth > 12 ? 4 : 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductiveTimeCard extends StatelessWidget {
  const ProductiveTimeCard({
    super.key,
    required this.stats,
    required this.accent,
  });

  final FocusStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final window = stats.productiveWindow;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(window.icon, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Productive Time',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  window.title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (window.percentage > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(window.percentage * 100).toInt()}% of focus',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FocusMilestonesSection extends StatelessWidget {
  const FocusMilestonesSection({
    super.key,
    required this.milestones,
    required this.accent,
  });

  final List<FocusMilestone> milestones;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return StatCard(
      title: 'Milestones & Achievements',
      icon: LucideIcons.award,
      color: accent,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final m in milestones)
            Container(
              width: 220,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: m.isUnlocked
                    ? accent.withValues(alpha: 0.08)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: m.isUnlocked
                      ? accent.withValues(alpha: 0.3)
                      : scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        m.icon,
                        size: 20,
                        color: m.isUnlocked ? accent : context.tokens.muted,
                      ),
                      if (m.isUnlocked)
                        const Icon(LucideIcons.circleCheck, size: 16, color: Colors.green)
                      else
                        Text(
                          '${m.progress}/${m.target} ${m.unit}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.tokens.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    m.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: m.isUnlocked ? scheme.onSurface : context.tokens.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: m.percentage,
                      minHeight: 5,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        m.isUnlocked ? Colors.green : accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
