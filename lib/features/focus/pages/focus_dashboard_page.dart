import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/extensions/inset_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/app_confirm_dialog.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/data/focus_stats.dart';
import 'package:streak/features/focus/state/focus_actions.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_analytics_widgets.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_header.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_widgets.dart';
import 'package:streak/features/focus/widgets/focus_history_dialog.dart';
import 'package:streak/features/focus/widgets/focus_period_bar.dart';
import 'package:streak/features/focus/widgets/focus_period_sessions_dialog.dart';
import 'package:streak/features/focus/widgets/focus_pill.dart';
import 'package:streak/features/focus/widgets/focus_range_bars.dart';
import 'package:streak/features/focus/widgets/focus_setup_dialog.dart';
import 'package:streak/features/focus/widgets/focus_tab_bar.dart';
import 'package:streak/features/focus/widgets/focus_time_of_day_card.dart';
import 'package:streak/features/focus/widgets/focus_weekday_averages_card.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';
import 'package:streak/features/statistics/widgets/stat_charts.dart';

const _lockInDarkGreen = Color(0xFF065F46);
const _lockInBright = Color(0xFF10B981);

class FocusDashboardPage extends StatefulWidget {
  const FocusDashboardPage({super.key});

  @override
  State<FocusDashboardPage> createState() => _FocusDashboardPageState();
}

class _FocusDashboardPageState extends State<FocusDashboardPage> {
  int _currentTab = 0; // 0 = Today, 1 = Analytics
  FocusRange _range = FocusRange.week;
  int _offset = 0;
  int _labelPeriodIndex = 0; // 0 = Week, 1 = Month, 2 = All time

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

  String _formatTodayTime(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
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

  Future<void> _deleteSession(
    BuildContext context,
    FocusController focus,
    FocusSession session,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.focus_delete_sessions,
      message: context.l10n.focus_delete_sessions_body(1),
      confirmLabel: context.l10n.delete,
    );
    if (confirmed != true || !context.mounted) return;

    final habits = context.read<HabitsController>();
    await countFocusTime(habits, focus, session, undo: true);
    await focus.removeSessions({session.id});
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

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

    final defaultDailyGoal =
        settings.focusDailyGoal > 0 ? settings.focusDailyGoal : 60;
    final currentDailyGoal = focus.dailyTargetFor(today, defaultDailyGoal);

    final defaultWeeklyHours = (defaultDailyGoal * 7) ~/ 60;
    final currentWeeklyHours = focus.weeklyTargetFor(
      today,
      defaultWeeklyHours <= 0 ? 10 : defaultWeeklyHours,
      weekStart: settings.weekStart,
    );

    return FocusTabShortcuts(
      tabCount: 2,
      index: _currentTab,
      onSelect: (i) => setState(() => _currentTab = i),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.focus,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 24),
              PillTabs(
                tabs: const ['Today', 'Analytics'],
                index: _currentTab,
                onChanged: (i) => setState(() => _currentTab = i),
              ),
            ],
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: ListView(
                padding: context.pagePadding(20, 12, 20, 96),
                children: [
                  // 1. Lifetime metrics strip
                  const FocusDashboardHeader(),
                  const SizedBox(height: 12),

                  // 2. Tab Body (Today vs Analytics)
                  if (_currentTab == 0)
                    _buildTodayTab(
                      context: context,
                      focus: focus,
                      habits: habits,
                      today: today,
                      todaySeconds: todaySeconds,
                      dailyGoalMinutes: currentDailyGoal,
                      settings: settings,
                    )
                  else
                    _buildAnalyticsTab(
                      context: context,
                      focus: focus,
                      stats: stats,
                      currentWeeklyHours: currentWeeklyHours,
                      settings: settings,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayTab({
    required BuildContext context,
    required FocusController focus,
    required HabitsController habits,
    required DateTime today,
    required int todaySeconds,
    required int dailyGoalMinutes,
    required SettingsController settings,
  }) {
    final dailyGoalSec = dailyGoalMinutes * 60;
    final dailyRatio =
        dailyGoalSec > 0 ? (todaySeconds / dailyGoalSec).clamp(0.0, 1.0) : 0.0;
    final dailyPercent = (dailyRatio * 100).round();
    final dailyHit = dailyGoalSec > 0 && todaySeconds >= dailyGoalSec;

    final todaySessions = focus.sessions
        .where((s) => s.countedOn.dayKey == today.dayKey)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final heroCard = _buildHeroCard(
      focus: focus,
      todaySeconds: todaySeconds,
      dailyGoalMinutes: dailyGoalMinutes,
      dailyRatio: dailyRatio,
      dailyPercent: dailyPercent,
      dailyHit: dailyHit,
    );

    final sessionsColumn = _buildSessionsColumn(
      focus: focus,
      habits: habits,
      today: today,
      todaySessions: todaySessions,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 780;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: heroCard),
                  const SizedBox(width: 48),
                  Expanded(flex: 6, child: sessionsColumn),
                ],
              )
            else ...[
              heroCard,
              const SizedBox(height: 20),
              sessionsColumn,
            ],
            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: context.colors.outlineVariant.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.6,
                child: WeeklyContinuousTimeline(
                  sessions: focus.sessions,
                  accent: _lockInBright,
                  weekStart: settings.weekStart,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroCard({
    required FocusController focus,
    required int todaySeconds,
    required int dailyGoalMinutes,
    required double dailyRatio,
    required int dailyPercent,
    required bool dailyHit,
  }) {
    final scheme = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goalLabel = dailyGoalMinutes >= 60
        ? '${(dailyGoalMinutes / 60).toStringAsFixed(dailyGoalMinutes % 60 == 0 ? 0 : 1)}h'
        : '${dailyGoalMinutes}m';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TODAY'S FOCUS TIME",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: context.tokens.muted,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dailyHit) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
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
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '$dailyPercent%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _lockInBright,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.pencil, size: 14),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: context.tokens.muted,
                    onPressed: () => _showEditDailyTargetDialog(
                      context,
                      focus,
                      dailyGoalMinutes,
                    ),
                    tooltip: 'Set daily goal',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _formatTodayTime(todaySeconds),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                color: isDark ? Colors.white : _lockInDarkGreen,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatHoursShort(todaySeconds)} / $goalLabel',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (dailyHit)
                Text(
                  'Goal reached',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: dailyRatio,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(_lockInBright),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _startFocus(context, focus),
              style: FilledButton.styleFrom(
                backgroundColor: _lockInDarkGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: Icon(
                focus.isCompleted
                    ? LucideIcons.check
                    : (focus.isActive ? LucideIcons.flame : LucideIcons.play),
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                focus.isCompleted
                    ? 'Session Complete'
                    : (focus.isActive ? 'Active Session' : 'Start Session'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (focus.isActive) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => openFocus(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      focus.isCompleted
                          ? LucideIcons.circleCheck
                          : (focus.isRunning
                              ? LucideIcons.timer
                              : LucideIcons.pause),
                      size: 14,
                      color: focus.isCompleted
                          ? context.tokens.success
                          : (focus.isRunning
                              ? _lockInBright
                              : context.tokens.warning),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      focus.isCompleted
                          ? 'Session complete! 🎉 · Tap to review'
                          : (focus.isRunning
                              ? 'Session running · ${formatDuration(focus.displaySeconds)} • Tap to view'
                              : 'Session paused · ${formatDuration(focus.displaySeconds)} • Tap to resume'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: focus.isCompleted
                            ? context.tokens.success
                            : (focus.isRunning
                                ? (isDark ? _lockInBright : _lockInDarkGreen)
                                : context.tokens.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionsColumn({
    required FocusController focus,
    required HabitsController habits,
    required DateTime today,
    required List<FocusSession> todaySessions,
  }) {
    final scheme = context.colors;
    final visible = todaySessions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  "Today's Sessions",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (todaySessions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${todaySessions.length}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.tokens.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            TextButton.icon(
              onPressed: () => showFocusHistoryDialog(context),
              icon: const Icon(LucideIcons.history, size: 14),
              label: const Text('All History',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (todaySessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.clock, size: 28, color: context.tokens.muted),
                const SizedBox(height: 10),
                Text(
                  'No focus sessions recorded today yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.muted,
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final session in visible)
            FocusSessionCard(
              session: session,
              habit: session.habitId.isEmpty
                  ? null
                  : habits.byId(session.habitId),
              onDelete: () => _deleteSession(context, focus, session),
            ),
          if (todaySessions.length > visible.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: () => _openTodaySessionsDialog(focus, today),
                icon: const Icon(LucideIcons.listCollapse, size: 15),
                label: Text('See all ${todaySessions.length} sessions'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  void _openTodaySessionsDialog(FocusController focus, DateTime today) {
    showPeriodSessionsDialog(
      context: context,
      title: DateFormat('EEE, MMM d').format(today),
      start: today,
      end: today.add(const Duration(days: 1)),
      filter: (session) => session.countedOn.dayKey == today.dayKey,
      onDelete: (session) => _deleteSession(context, focus, session),
    );
  }

  Widget _buildAnalyticsTab({
    required BuildContext context,
    required FocusController focus,
    required FocusStats stats,
    required int currentWeeklyHours,
    required SettingsController settings,
  }) {
    final labelPeriod = _labelPeriodIndex == 0
        ? 'week'
        : (_labelPeriodIndex == 1 ? 'month' : 'all');
    final labelEntries =
        focus.labelRankingForPeriod(labelPeriod, settings.weekStart);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final scheme = context.colors;

        // Row 1: Weekly Target card & 2×2 KPI grid
        final weeklyTargetCard = WeeklyFocusComparisonCard(
          stats: stats,
          targetHours: currentWeeklyHours,
          accent: _lockInBright,
          onEditTarget: () => _showEditWeeklyTargetDialog(
            context,
            focus,
            currentWeeklyHours,
            settings.weekStart,
          ),
        );

        final kpiGrid = FocusKpiGrid(
          stats: stats,
          accent: _lockInBright,
        );

        // Row 2: Focus Time Range Chart — flat container (no StatCard wrapper)
        final focusChartCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Focus Time',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  Segmented(
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
                ],
              ),
              const SizedBox(height: 14),
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
                onBarTap: (start, end, title) => showPeriodSessionsDialog(
                  context: context,
                  title: title,
                  start: start,
                  end: end,
                  onDelete: (session) =>
                      _deleteSession(context, focus, session),
                ),
              ),
            ],
          ),
        );

        // Row 3: Day of week and Time of day — equal height via IntrinsicHeight
        final weekdayCard = FocusWeekdayAveragesCard(
          focus: focus,
          weekStart: settings.weekStart,
          accent: _lockInBright,
        );

        // ProductiveTimeCard removed — Time of Day breakdown is sufficient
        final timeOfDayCard = FocusTimeOfDayCard(
          focus: focus,
          weekStart: settings.weekStart,
          accent: _lockInBright,
        );

        // Row 4: Focused on (by label)
        final focusedOnCard = Container(
          padding: const EdgeInsets.all(20),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (ctx, c) {
                      final isCompact = c.maxWidth < 340;
                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Focused on',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Segmented(
                              options: const ['Week', 'Month', 'All Time'],
                              index: _labelPeriodIndex,
                              onChanged: (idx) =>
                                  setState(() => _labelPeriodIndex = idx),
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Focused on',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Segmented(
                            options: const ['Week', 'Month', 'All Time'],
                            index: _labelPeriodIndex,
                            onChanged: (idx) =>
                                setState(() => _labelPeriodIndex = idx),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FocusTagCloud(
                    entries: labelEntries,
                    focus: focus,
                  ),
                ],
              ),
            ),
          ),
        );

        // Row 5: Activity heatmap - flat container, FocusActivityMap fills width
        final heatmapCard = Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activity Map',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              FocusActivityMap(
                sessions: focus.sessions,
                color: _lockInBright,
              ),
            ],
          ),
        );

        // Add clipBehavior to Row 1 and 2 cards to prevent overflow
        
        return Column(
          children: [
            // Row 1: Weekly Target + KPIs (IntrinsicHeight so both match)
            if (isWide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                        child: weeklyTargetCard,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                        child: kpiGrid,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              weeklyTargetCard,
              const SizedBox(height: 16),
              kpiGrid,
            ],
            const SizedBox(height: 16),

            // Row 2: Focus time chart (flat, no Card/scrollbar artifact)
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
              child: focusChartCard,
            ),
            const SizedBox(height: 16),

            // Row 3: Day of week and Time of day (IntrinsicHeight for equal height)
            if (isWide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                        child: weekdayCard,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                        child: timeOfDayCard,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              weekdayCard,
              const SizedBox(height: 16),
              timeOfDayCard,
            ],
            const SizedBox(height: 16),

            // Row 4: Activity heatmap (now above focused on)
            heatmapCard,
            const SizedBox(height: 16),

            // Row 5: Focused on (by label), full width
            focusedOnCard,
          ],
        );
      },
    );
  }
}
