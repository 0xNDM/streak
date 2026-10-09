import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/extensions/inset_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/entrance.dart';
import 'package:streak/core/widgets/stat_columns.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/data/focus_stats.dart';
import 'package:streak/features/focus/state/focus_actions.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_analytics_widgets.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_widgets.dart';
import 'package:streak/features/focus/widgets/focus_history_dialog.dart';
import 'package:streak/features/focus/widgets/focus_period_bar.dart';
import 'package:streak/features/focus/widgets/focus_pill.dart';
import 'package:streak/features/focus/widgets/focus_range_bars.dart';
import 'package:streak/features/focus/widgets/focus_setup_dialog.dart';
import 'package:streak/features/focus/widgets/focus_time_of_day_card.dart';
import 'package:streak/features/focus/widgets/focus_weekday_averages_card.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';
import 'package:streak/features/statistics/widgets/stat_charts.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';

const _entrance = Duration(milliseconds: 320);
const _lockInGreen = Color(0xFF047857);
const _lockInDarkGreen = Color(0xFF065F46);
const _lockInBright = Color(0xFF10B981);

class FocusDashboardPage extends StatefulWidget {
  const FocusDashboardPage({super.key});

  @override
  State<FocusDashboardPage> createState() => _FocusDashboardPageState();
}

class _FocusDashboardPageState extends State<FocusDashboardPage> {
  FocusRange _range = FocusRange.week;
  int _offset = 0;

  void _startFocus(BuildContext context, FocusController focus) {
    if (focus.isActive) {
      openFocus(context);
    } else {
      if (Platform.isWindows) {
        showFocusSetupDialog(context);
      } else {
        openFocus(context);
      }
    }
  }

  Future<void> _showEditDailyTargetDialog(
    BuildContext context,
    FocusController focus,
    int currentMinutes,
  ) async {
    final controller = TextEditingController(
      text: currentMinutes > 0 ? '$currentMinutes' : '60',
    );
    final presets = [30, 45, 60, 90, 120, 180, 240];
    int selected = currentMinutes;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final today = AppClock.now();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Daily Target (${DateFormat('EEE, MMM d').format(today)})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set independent focus target for today. Changing this does not alter past or future day goals.',
                  style: TextStyle(fontSize: 13, color: ctx.tokens.muted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in presets)
                      ChoiceChip(
                        label: Text(
                          p >= 60
                              ? '${(p / 60).toStringAsFixed(p % 60 == 0 ? 0 : 1)}h'
                              : '${p}m',
                        ),
                        selected: selected == p,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              selected = p;
                              controller.text = '$p';
                            });
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target in minutes',
                    hintText: 'e.g. 90',
                    suffixText: 'mins',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null) {
                      setDialogState(() => selected = parsed);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _lockInDarkGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final target = int.tryParse(controller.text) ?? selected;
                  if (target > 0) {
                    await focus.setDailyTarget(today, target);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Target'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditWeeklyTargetDialog(
    BuildContext context,
    FocusController focus,
    int currentHours,
    int weekStart,
  ) async {
    final controller = TextEditingController(
      text: currentHours > 0 ? '$currentHours' : '10',
    );
    final presets = [5, 10, 15, 20, 25, 30, 40];
    int selected = currentHours;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final today = AppClock.now();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Weekly Target',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set independent focus target for this week. Changing this does not alter other weeks.',
                  style: TextStyle(fontSize: 13, color: ctx.tokens.muted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in presets)
                      ChoiceChip(
                        label: Text('${p}h'),
                        selected: selected == p,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              selected = p;
                              controller.text = '$p';
                            });
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target in hours',
                    hintText: 'e.g. 15',
                    suffixText: 'hours',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null) {
                      setDialogState(() => selected = parsed);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _lockInDarkGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final target = int.tryParse(controller.text) ?? selected;
                  if (target > 0) {
                    await focus.setWeeklyTarget(
                      today,
                      target,
                      weekStart: weekStart,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Target'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<({String name, Color color, int count})> _ranking(
    FocusStats stats,
    HabitsController habits,
    Color accent,
  ) {
    final entries = [
      for (final entry in stats.perHabit.entries)
        (
          name: habits.byId(entry.key)?.name ?? context.l10n.focus_free_session,
          color: habits.byId(entry.key)?.color ?? accent,
          count: entry.value,
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return entries.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final scheme = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    context.select<FocusController, int>((f) => f.revision);
    final focus = context.watch<FocusController>();
    final habits = context.watch<HabitsController>();

    final today = AppClock.now();
    final todaySeconds = focus.secondsForDay(today);

    final stats = FocusStats.compute(
      sessions: focus.sessions,
      range: _range,
      offset: _offset,
      now: today,
      weekStart: settings.weekStart,
    );

    final defaultDailyGoal = settings.focusDailyGoal > 0 ? settings.focusDailyGoal : 60;
    final currentDailyGoal = focus.dailyTargetFor(today, defaultDailyGoal);

    final defaultWeeklyHours = (defaultDailyGoal * 7) ~/ 60;
    final currentWeeklyHours = focus.weeklyTargetFor(
      today,
      defaultWeeklyHours <= 0 ? 10 : defaultWeeklyHours,
      weekStart: settings.weekStart,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.focus,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        actions: [
          // Start Session Button (dark green lock-in styling)
          FilledButton.icon(
            onPressed: () => _startFocus(context, focus),
            style: FilledButton.styleFrom(
              backgroundColor: _lockInDarkGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: Icon(
              focus.isActive ? LucideIcons.flame : LucideIcons.play,
              size: 15,
              color: Colors.white,
            ),
            label: Text(
              focus.isActive ? 'Active Session' : 'Start Session',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // White History Icon (standalone button, no text, opens popup dialog)
          Tooltip(
            message: 'Focus History',
            child: InkWell(
              onTap: () => showFocusHistoryDialog(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  LucideIcons.history,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: context.pagePadding(16, 8, 16, 96),
          children: spanned(context, [
            // 1. Hero KPI Banner & Independent Targets
            Entrance(
              index: 0,
              delay: _entrance,
              child: _buildHeroSection(
                context: context,
                focus: focus,
                stats: stats,
                todaySeconds: todaySeconds,
                dailyGoalMinutes: currentDailyGoal,
                weeklyGoalHours: currentWeeklyHours,
                weekStart: settings.weekStart,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 16),

            // 2. Focus Time Range Chart (Before Continuous Timeline)
            Entrance(
              index: 1,
              delay: _entrance,
              child: StatCard(
                title: context.l10n.focus_total,
                icon: LucideIcons.chartColumn,
                color: _lockInBright,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Segmented(
                        options: [
                          context.l10n.week,
                          context.l10n.month,
                          context.l10n.year,
                        ],
                        index: FocusRange.values.indexOf(_range),
                        onChanged: (index) => setState(() {
                          _range = FocusRange.values[index];
                          _offset = 0;
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FocusPeriodBar(
                      range: _range,
                      offset: _offset,
                      stats: stats,
                      accent: _lockInBright,
                      onOffset: (value) => setState(() => _offset = value),
                    ),
                    const SizedBox(height: 14),
                    FocusRangeBars(
                      stats: stats,
                      range: _range,
                      color: _lockInBright,
                    ),
                  ],
                ),
              ),
            ),

            // SpanEnd: below this, cards adapt into 2 balanced columns when maximized on desktop
            const SpanEnd(),
            const SizedBox(height: 16),

            // 3. Weekly Continuous Timeline
            Entrance(
              index: 2,
              delay: _entrance,
              child: WeeklyContinuousTimeline(
                sessions: focus.sessions,
                accent: _lockInBright,
              ),
            ),
            const SizedBox(height: 16),

            // 4. Day of Week Averages & Monthly Breakdown
            Entrance(
              index: 3,
              delay: _entrance,
              child: FocusWeekdayAveragesCard(
                focus: focus,
                weekStart: settings.weekStart,
                accent: _lockInBright,
              ),
            ),
            const SizedBox(height: 16),

            // 5. Time of Day Breakdown
            Entrance(
              index: 4,
              delay: _entrance,
              child: FocusTimeOfDayCard(
                focus: focus,
                weekStart: settings.weekStart,
                accent: _lockInBright,
              ),
            ),
            const SizedBox(height: 16),

            // 6. Most Productive Window
            Entrance(
              index: 5,
              delay: _entrance,
              child: ProductiveTimeCard(
                stats: stats,
                accent: _lockInBright,
              ),
            ),
            const SizedBox(height: 16),

            // 7. Executive KPI Grid
            Entrance(
              index: 6,
              delay: _entrance,
              child: FocusKpiGrid(
                stats: stats,
                accent: _lockInBright,
              ),
            ),
            const SizedBox(height: 16),

            // 8. Weekly Comparison Card
            Entrance(
              index: 7,
              delay: _entrance,
              child: WeeklyFocusComparisonCard(
                stats: stats,
                targetHours: currentWeeklyHours,
                accent: _lockInBright,
                onEditTarget: () => _showEditWeeklyTargetDialog(
                  context,
                  focus,
                  currentWeeklyHours,
                  settings.weekStart,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 9. Habit & Label Rankings
            if (stats.perHabit.length > 1) ...[
              Entrance(
                index: 8,
                delay: _entrance,
                child: StatCard(
                  title: context.l10n.by_habit,
                  icon: LucideIcons.listOrdered,
                  color: _lockInBright,
                  child: HabitRanking(
                    entries: _ranking(stats, habits, _lockInBright),
                    format: formatHoursShort,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (stats.perLabel.isNotEmpty) ...[
              Entrance(
                index: 9,
                delay: _entrance,
                child: StatCard(
                  title: context.l10n.by_label,
                  icon: LucideIcons.tag,
                  color: _lockInBright,
                  child: HabitRanking(
                    entries: [
                      for (final entry in stats.labelRanking)
                        (
                          name: '#${entry.key}',
                          color: focus.colorForLabel(entry.key),
                          count: entry.value,
                        ),
                    ],
                    format: formatHoursShort,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 10. Activity Map
            Entrance(
              index: 10,
              delay: _entrance,
              child: StatCard(
                title: 'Activity Map',
                icon: LucideIcons.layoutGrid,
                color: _lockInBright,
                child: FocusActivityMap(
                  sessions: focus.sessions,
                  color: _lockInBright,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeroSection({
    required BuildContext context,
    required FocusController focus,
    required FocusStats stats,
    required int todaySeconds,
    required int dailyGoalMinutes,
    required int weeklyGoalHours,
    required int weekStart,
    required bool isDark,
  }) {
    final scheme = context.colors;

    final totalSec = focus.totalSeconds;
    final totalHours = totalSec / 3600;
    final totalHoursStr = totalHours >= 100
        ? '${totalHours.toStringAsFixed(0)}h'
        : totalHours >= 10
            ? '${totalHours.toStringAsFixed(1)}h'
            : formatHoursShort(totalSec);

    final activeDays = focus.totalActiveDaysCount;
    final elapsedDays = focus.totalElapsedDaysSinceStart;
    final consistency = elapsedDays > 0 ? ((activeDays / elapsedDays) * 100).round() : 0;
    final firstDate = focus.firstSessionDate;

    // Today progress
    final dailyGoalSec = dailyGoalMinutes * 60;
    final dailyRatio = dailyGoalSec > 0 ? (todaySeconds / dailyGoalSec).clamp(0.0, 1.0) : 0.0;
    final dailyPercent = (dailyRatio * 100).round();
    final dailyHit = dailyGoalSec > 0 && todaySeconds >= dailyGoalSec;

    // Weekly progress
    final weeklyGoalSec = weeklyGoalHours * 3600;
    final weeklySec = stats.weekSeconds;
    final weeklyRatio = weeklyGoalSec > 0 ? (weeklySec / weeklyGoalSec).clamp(0.0, 1.0) : 0.0;
    final weeklyPercent = (weeklyRatio * 100).round();
    final weeklyHit = weeklyGoalSec > 0 && weeklySec >= weeklyGoalSec;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  _lockInDarkGreen.withValues(alpha: 0.35),
                  scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ]
              : [
                  _lockInGreen.withValues(alpha: 0.10),
                  _lockInBright.withValues(alpha: 0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _lockInBright.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Hours Focused Headline
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _lockInBright.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.flame,
                            size: 15,
                            color: _lockInBright,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TOTAL FOCUS TIME',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: context.tokens.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          totalHoursStr,
                          style: statNumber(
                            context,
                            40,
                            color: isDark ? Colors.white : _lockInDarkGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Focused',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      elapsedDays > 0
                          ? '$activeDays days active of $elapsedDays days • $consistency% consistency'
                          : '0 days active • Ready to begin',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                    if (firstDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Tracking since ${DateFormat('MMM d, yyyy').format(firstDate)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.tokens.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Active session strip
          if (focus.isActive) ...[
            const SizedBox(height: 18),
            InkWell(
              onTap: () => openFocus(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: _lockInDarkGreen.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lockInBright.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.timer, size: 18, color: _lockInBright),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Focus session in progress • Tap to open timer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : _lockInDarkGreen,
                        ),
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, size: 16, color: _lockInBright),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Independent Daily & Weekly Targets
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final todayCard = _buildTargetCard(
                context: context,
                title: "Today's Target",
                subtitle: DateFormat('EEE, MMM d').format(AppClock.now()),
                progressRatio: dailyRatio,
                percent: dailyPercent,
                isHit: dailyHit,
                valueText: '${formatHoursShort(todaySeconds)} / ${dailyGoalMinutes >= 60 ? '${(dailyGoalMinutes / 60).toStringAsFixed(dailyGoalMinutes % 60 == 0 ? 0 : 1)}h' : '${dailyGoalMinutes}m'}',
                onEdit: () => _showEditDailyTargetDialog(
                  context,
                  focus,
                  dailyGoalMinutes,
                ),
              );

              final weekCard = _buildTargetCard(
                context: context,
                title: 'Weekly Target',
                subtitle: 'Week ${FocusController.weekKey(AppClock.now(), weekStart).split('_').first}',
                progressRatio: weeklyRatio,
                percent: weeklyPercent,
                isHit: weeklyHit,
                valueText: '${formatHoursShort(weeklySec)} / ${weeklyGoalHours}h',
                onEdit: () => _showEditWeeklyTargetDialog(
                  context,
                  focus,
                  weeklyGoalHours,
                  weekStart,
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    todayCard,
                    const SizedBox(height: 10),
                    weekCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: todayCard),
                  const SizedBox(width: 12),
                  Expanded(child: weekCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double progressRatio,
    required int percent,
    required bool isHit,
    required String valueText,
    required VoidCallback onEdit,
  }) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _lockInBright.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'HIT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: _lockInBright,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.pencil, size: 14),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: context.tokens.muted,
                    onPressed: onEdit,
                    tooltip: 'Edit target',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _lockInBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(_lockInBright),
            ),
          ),
        ],
      ),
    );
  }
}
