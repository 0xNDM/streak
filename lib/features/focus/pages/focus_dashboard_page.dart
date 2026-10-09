import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/express/express_page.dart';
import 'package:streak/core/express/express_surface.dart';
import 'package:streak/core/express/express_tabs.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/extensions/inset_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/utils/app_snackbar.dart';
import 'package:streak/core/widgets/app_confirm_dialog.dart';
import 'package:streak/core/widgets/app_empty_state.dart';
import 'package:streak/core/widgets/entrance.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/data/focus_stats.dart';
import 'package:streak/features/focus/state/focus_actions.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_widgets.dart';
import 'package:streak/features/focus/widgets/focus_period_bar.dart';
import 'package:streak/features/focus/widgets/focus_pill.dart';
import 'package:streak/features/focus/widgets/focus_range_bars.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';
import 'package:streak/features/statistics/widgets/stat_charts.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';

const _entrance = Duration(milliseconds: 320);

class FocusDashboardPage extends StatefulWidget {
  const FocusDashboardPage({super.key});

  @override
  State<FocusDashboardPage> createState() => _FocusDashboardPageState();
}

class _FocusDashboardPageState extends State<FocusDashboardPage> {
  int _subTab = 0; // 0 = Today, 1 = Details
  FocusRange _range = FocusRange.week;
  int _offset = 0;

  Future<void> _deleteSession(BuildContext context, FocusSession session) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.focus_delete_sessions,
      message: context.l10n.focus_delete_sessions_body(1),
      confirmLabel: context.l10n.delete,
    );
    if (confirmed != true || !context.mounted) return;

    final focus = context.read<FocusController>();
    final habits = context.read<HabitsController>();
    await countFocusTime(habits, focus, session, undo: true);
    await focus.removeSessions({session.id});
    if (!context.mounted) return;
    AppSnackbar.success(context, context.l10n.focus_sessions_deleted(1));
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
    final express = settings.isExpressStyle;
    final minimal = settings.isMinimalStyle;
    final scheme = context.colors;
    final accent = scheme.primary;

    context.select<FocusController, int>((f) => f.revision);
    final focus = context.watch<FocusController>();
    final habits = context.watch<HabitsController>();

    final today = AppClock.now();
    final todaySessions = focus.sessions
        .where((s) => s.countedOn.dayKey == today.dayKey)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final todaySeconds = todaySessions.fold<int>(0, (sum, s) => sum + s.seconds);

    return Scaffold(
      appBar: AppBar(
        title: express
            ? ExpressHeadline(title: context.l10n.focus)
            : Text(
                context.l10n.focus,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: express
              ? context.pagePadding(18, 4, 18, 32)
              : minimal
              ? context.pagePadding(20, 4, 20, 32)
              : context.pagePadding(16, 4, 16, 32),
          children: [
            _buildSubTabs(context, express),
            const SizedBox(height: 18),
            if (_subTab == 0)
              _buildTodayView(
                context,
                focus,
                habits,
                settings,
                todaySeconds,
                todaySessions,
              )
            else
              _buildDetailsView(
                context,
                focus,
                habits,
                settings,
                accent,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabs(BuildContext context, bool express) {
    final labels = [context.l10n.today, 'Details'];
    if (express) {
      return ExpressTabs(
        labels: labels,
        index: _subTab,
        onChanged: (index) => setState(() => _subTab = index),
      );
    }

    final scheme = context.colors;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              GestureDetector(
                onTap: () => setState(() => _subTab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _subTab == i
                        ? scheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _subTab == i
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _subTab == i ? FontWeight.w800 : FontWeight.w600,
                      color: _subTab == i
                          ? scheme.onSurface
                          : context.tokens.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayView(
    BuildContext context,
    FocusController focus,
    HabitsController habits,
    SettingsController settings,
    int todaySeconds,
    List<FocusSession> todaySessions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrance(
          index: 0,
          delay: _entrance,
          child: FocusTodayHero(
            todaySeconds: todaySeconds,
            sessionCount: todaySessions.length,
            dailyGoalMinutes: settings.focusDailyGoal,
            onStartSession: () => openFocus(context),
          ),
        ),
        const SizedBox(height: 24),
        Entrance(
          index: 1,
          delay: _entrance,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Sessions",
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (todaySessions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${todaySessions.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.tokens.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (todaySessions.isEmpty)
          Entrance(
            index: 2,
            delay: _entrance,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.colors.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.hourglass,
                    size: 32,
                    color: context.tokens.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No sessions today yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Start session" above to begin your focus block.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final (index, session) in todaySessions.indexed)
            Entrance(
              key: ValueKey(session.id),
              index: index + 2,
              delay: _entrance,
              child: FocusSessionCard(
                session: session,
                habit: session.habitId.isEmpty
                    ? null
                    : habits.byId(session.habitId),
                onDelete: () => _deleteSession(context, session),
              ),
            ),
      ],
    );
  }

  Widget _buildDetailsView(
    BuildContext context,
    FocusController focus,
    HabitsController habits,
    SettingsController settings,
    Color accent,
  ) {
    final stats = FocusStats.compute(
      sessions: focus.sessions,
      range: _range,
      offset: _offset,
      now: AppClock.now(),
      weekStart: settings.weekStart,
    );

    if (stats.sessionCount == 0) {
      return AppEmptyState(
        icon: LucideIcons.timer,
        title: context.l10n.no_data_yet,
        message: context.l10n.focus_history_empty_sub,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FocusMetricCard(
                title: context.l10n.week,
                value: formatHoursShort(stats.weekSeconds),
                icon: LucideIcons.calendarDays,
                accent: context.tokens.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FocusMetricCard(
                title: context.l10n.month,
                value: formatHoursShort(stats.monthSeconds),
                icon: LucideIcons.calendarRange,
                accent: context.tokens.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FocusMetricCard(
                title: context.l10n.focus_total,
                value: formatHoursShort(stats.totalSeconds),
                icon: LucideIcons.timer,
                accent: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FocusMetricCard(
                title: context.l10n.focus_average,
                value: formatHoursShort(stats.averageSeconds),
                icon: LucideIcons.activity,
                accent: context.tokens.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StatCard(
          title: context.l10n.focus_total,
          icon: LucideIcons.chartColumn,
          color: accent,
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
                accent: accent,
                onOffset: (value) => setState(() => _offset = value),
              ),
              const SizedBox(height: 14),
              FocusRangeBars(
                stats: stats,
                range: _range,
                color: accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        StatCard(
          title: 'Activity Map',
          icon: LucideIcons.layoutGrid,
          color: accent,
          child: FocusActivityMap(
            sessions: focus.sessions,
            color: accent,
          ),
        ),
        if (stats.perHabit.length > 1) ...[
          const SizedBox(height: 16),
          StatCard(
            title: context.l10n.by_habit,
            icon: LucideIcons.listOrdered,
            color: accent,
            child: HabitRanking(
              entries: _ranking(stats, habits, accent),
              format: formatHoursShort,
            ),
          ),
        ],
        if (stats.perLabel.isNotEmpty) ...[
          const SizedBox(height: 16),
          StatCard(
            title: context.l10n.by_label,
            icon: LucideIcons.tag,
            color: accent,
            child: HabitRanking(
              entries: [
                for (final entry in stats.labelRanking)
                  (name: entry.key, color: accent, count: entry.value),
              ],
              format: formatHoursShort,
            ),
          ),
        ],
      ],
    );
  }
}
