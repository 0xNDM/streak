import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/data/focus_stats.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_widgets.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/settings/state/settings_controller.dart';

class WeeklyFocusComparisonCard extends StatelessWidget {
  const WeeklyFocusComparisonCard({
    super.key,
    required this.stats,
    required this.targetHours,
    required this.accent,
    this.onEditTarget,
  });

  final FocusStats stats;
  final int targetHours;
  final Color accent;
  final VoidCallback? onEditTarget;

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.6)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.focus_weekly_focus_target,
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
                      if (onEditTarget != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onEditTarget,
                          child: Icon(
                            LucideIcons.pencil,
                            size: 14,
                            color: context.tokens.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox.shrink(),
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
                context.l10n.focus_percent_of_weekly_target(
                  (progress * 100).toInt(),
                ),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.muted,
                ),
              ),
              Text(
                isReached
                    ? context.l10n.focus_target_reached
                    : context.l10n
                        .focus_hours_to_go(remainingHours.toStringAsFixed(1)),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isReached
                      ? context.tokens.success
                      : context.tokens.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2×2 KPI grid: Longest Session, Best Focus Day, This Month, Longest Streak.
/// Today and Week tiles removed — they are already visible in the header strip
/// and the Weekly Target card respectively.
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
    final dateFormat =
        DateFormat.MMMd(Localizations.localeOf(context).toString());
    final bestDayLabel = stats.longestDayDate == null
        ? ''
        : ' (${dateFormat.format(stats.longestDayDate!)})';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FocusMetricCard(
                title: context.l10n.focus_longest_session,
                value: formatHoursShort(stats.longestSessionSeconds),
                icon: LucideIcons.timer,
                accent: context.tokens.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FocusMetricCard(
                title: context.l10n.focus_best_focus_day,
                value:
                    '${formatHoursShort(stats.longestDaySeconds)}$bestDayLabel',
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
                title: context.l10n.focus_this_month,
                value: formatHoursShort(stats.monthSeconds),
                icon: LucideIcons.calendarRange,
                accent: const Color(0xFFF97316),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FocusMetricCard(
                title: context.l10n.focus_longest_streak,
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
    this.weekStart = 1,
  });

  final List<FocusSession> sessions;
  final Color accent;
  final int weekStart;

  @override
  State<WeeklyContinuousTimeline> createState() =>
      _WeeklyContinuousTimelineState();
}

class _WeeklyContinuousTimelineState extends State<WeeklyContinuousTimeline> {
  int _weekOffset = 0;

  DateTime get _now => AppClock.now();

  DateTime _computeWeekStart(int weekStart) {
    final today =
        _now.subtract(Duration(hours: AppClock.cutoffHour)).atMidnight;
    final anchor = today.startOfWeek(weekStart);
    return anchor.add(Duration(days: _weekOffset * 7));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final focus = context.read<FocusController>();
    final habits = context.watch<HabitsController>();
    final settings = context.watch<SettingsController>();
    final activeWeekStart =
        widget.weekStart == 1 ? settings.weekStart : widget.weekStart;
    final start = _computeWeekStart(activeWeekStart);
    final end = start.add(const Duration(days: 6));
    final formatRange =
        DateFormat.MMMd(Localizations.localeOf(context).toString());
    final rangeText =
        '${formatRange.format(start)} – ${formatRange.format(end)}, ${start.year}';

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.6)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
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
                  Text(
                    context.l10n.focus_weekly_timeline,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      context.l10n
                          .focus_total_time(formatHoursShort(weekTotalSeconds)),
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
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _weekOffset = 0),
                      child: Text(context.l10n.today,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.chevronRight, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: _weekOffset >= 0
                        ? null
                        : () => setState(() => _weekOffset++),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Time ruler
          Row(
            children: [
              const SizedBox(width: 58),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final t in const [
                      '00:00',
                      '04:00',
                      '08:00',
                      '12:00',
                      '16:00',
                      '20:00',
                      '24:00',
                    ])
                      Text(
                        t,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 58,
                child: Text(
                  'Total',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.muted,
                  ),
                ),
              ),
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

  String _formatDayTotal(int seconds) {
    if (seconds <= 0) return '0m';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final dayLabelFormat =
        DateFormat('E d', Localizations.localeOf(context).toString());
    final label = dayLabelFormat.format(date);
    final isToday = date.dayKey == AppClock.now().dayKey;
    final dayFocusSeconds = sessions.fold<int>(0, (sum, s) => sum + s.seconds);

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
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                height: 26,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.07),
                  ),
                ),
                child: Stack(
                  children: [
                    for (var h = 4; h <= 20; h += 4)
                      Positioned(
                        left: (h / 24.0) * totalWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                    for (final session in sessions)
                      _buildSessionPill(context, session, totalWidth),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 58,
          child: Text(
            dayFocusSeconds > 0 ? _formatDayTotal(dayFocusSeconds) : '0m',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  dayFocusSeconds > 0 ? FontWeight.w700 : FontWeight.w500,
              color: dayFocusSeconds > 0
                  ? (isToday ? defaultAccent : context.tokens.muted)
                  : context.tokens.muted.withValues(alpha: 0.4),
              fontFeatures: const [FontFeature.tabularFigures()],
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
    if (totalWidth <= 4.0) return const SizedBox.shrink();
    final start = session.startedAt;
    final startMinutes = start.hour * 60 + start.minute;
    final spanSeconds = math.max(
      session.seconds,
      session.endedAt.difference(start).inSeconds,
    );
    final spanMinutes = (spanSeconds / 60).clamp(1.0, 1440.0);

    final leftPos = (startMinutes / 1440.0) * totalWidth;
    final maxPillWidth = math.max(4.0, totalWidth);
    final pillWidth =
        ((spanMinutes / 1440.0) * totalWidth).clamp(4.0, maxPillWidth);
    final maxLeft = math.max(0.0, totalWidth - pillWidth);
    final safeLeft = leftPos.clamp(0.0, maxLeft);

    final habit = habits.byId(session.habitId);
    final firstTag = session.labelIds.isEmpty ? '' : session.labelIds.first;
    final tagColor = firstTag.isNotEmpty ? focus.colorForLabel(firstTag) : null;
    final color = tagColor ?? habit?.color ?? defaultAccent;

    final timeFormat = DateFormat('HH:mm');
    final endTime = session.endedAt;
    final timeStr =
        '${timeFormat.format(start)} – ${timeFormat.format(endTime)}';
    final habitTitle = habit?.name ?? context.l10n.focus;
    final labelNames = focus.labelNames(session.labelIds);
    final tagsStr = labelNames.isEmpty ? '' : ' [${labelNames.join(', ')}]';
    final String timeInfo;
    if (session.hasPauses) {
      final pauseMin = (session.pauseSeconds / 60).round();
      final pauseStr = pauseMin < 60
          ? '${pauseMin}m'
          : (pauseMin % 60 == 0
              ? '${pauseMin ~/ 60}h'
              : '${pauseMin ~/ 60}h ${pauseMin % 60}m');
      timeInfo =
          '$timeStr · ${formatHoursShort(session.seconds)} focus (${pauseStr} paused) · ${session.intensityPercent}%';
    } else {
      timeInfo = '$timeStr (${formatHoursShort(session.seconds)})';
    }
    final tooltipText = '$habitTitle$tagsStr\n$timeInfo';

    return Positioned(
      left: safeLeft,
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
            borderRadius: BorderRadius.circular(pillWidth > 12 ? 5 : 2),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.6,
              ),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: pillWidth >= 36
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      formatHoursShort(session.seconds),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Renders a proportional bubble cloud for focus labels based on their total duration.
class FocusTagCloud extends StatelessWidget {
  const FocusTagCloud({
    super.key,
    required this.entries,
    required this.focus,
  });

  final List<MapEntry<String, int>> entries;
  final FocusController focus;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            context.l10n.focus_no_tag_data,
            style: TextStyle(
              fontSize: 13,
              color: context.tokens.muted,
            ),
          ),
        ),
      );
    }

    final maxCount = entries.fold<int>(0, (max, e) => e.value > max ? e.value : max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubble = math.min(
          190.0,
          math.max(54.0, constraints.maxWidth - 8),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final entry in entries)
                  Builder(
                    builder: (context) {
                      final share = maxCount == 0
                          ? 0.0
                          : (entry.value / maxCount).clamp(0.0, 1.0);
                      // Map area linearly -> scale radius by square root
                      final scale = math.sqrt(share);
                      final bubbleSize = 54.0 + ((maxBubble - 54.0) * scale);

                      final tagColor = focus.colorForLabel(entry.key);
                      final durationStr = formatHoursShort(entry.value);
                      final innerSize = bubbleSize * 0.75;
                      final displayName = focus.labelDisplayName(entry.key);

                      // If exactly 2 words, explicitly put them on 2 lines so they fit nicely.
                      // Otherwise, let it be 1 line. We do NOT constrain the width of the Text,
                      // so a single word is never cut/broken. The FittedBox handles scaling it down.
                      final words = displayName.trim().split(RegExp(r'\s+'));
                      final formattedText = words.length == 2
                          ? '${words[0]}\n${words[1]}'
                          : displayName;

                      return Tooltip(
                        message: '$durationStr - $displayName',
                        waitDuration: const Duration(milliseconds: 300),
                        child: Container(
                          width: bubbleSize,
                          height: bubbleSize,
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tagColor.withValues(alpha: 0.3),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: innerSize,
                            height: innerSize,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formattedText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16 + (14 * scale),
                                    fontWeight: FontWeight.w800,
                                    color: tagColor,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
