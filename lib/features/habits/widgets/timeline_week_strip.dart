import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/express/express_button.dart';
import 'package:streak/core/express/express_motion.dart';
import 'package:streak/core/express/express_type.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/date_labels.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/minimal/minimal_type.dart';
import 'package:streak/features/habits/data/day_plan.dart';
import 'package:streak/features/habits/data/habit.dart';

typedef DayTally = ({int done, int due});

class TimelineWeekStrip extends StatelessWidget {
  const TimelineWeekStrip({
    super.key,
    required this.first,
    required this.selected,
    required this.habits,
    required this.style,
    required this.direction,
    required this.onSelected,
    required this.onShift,
  });

  final DateTime first;
  final DateTime selected;
  final List<Habit> habits;
  final int style;
  final int direction;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<int> onShift;

  static final _weeks = Expando<(int, List<int>)>();

  static List<int> _marks(Habit habit, DateTime first, List<DateTime> days) {
    final cached = _weeks[habit];
    if (cached != null && cached.$1 == first.epochDay) return cached.$2;
    final marks = List.filled(7, 0);
    if (!habit.tracking) {
      for (var i = 0; i < 7; i++) {
        if (!DayPlan.isDueOn(habit, days[i])) continue;
        marks[i] = habit.isCompletedOn(days[i]) ? 2 : 1;
      }
    }
    _weeks[habit] = (first.epochDay, marks);
    return marks;
  }

  static List<DayTally> tallies(List<Habit> habits, DateTime first) {
    final days = [for (var i = 0; i < 7; i++) first.addDays(i)];
    final done = List.filled(7, 0);
    final due = List.filled(7, 0);
    for (final habit in habits) {
      final marks = _marks(habit, first, days);
      for (var i = 0; i < 7; i++) {
        if (marks[i] > 0) due[i]++;
        if (marks[i] == 2) done[i]++;
      }
    }
    return [for (var i = 0; i < 7; i++) (done: done[i], due: due[i])];
  }

  String _range(String locale) {
    final format = DateFormat.MMMd(locale);
    return '${format.format(first)} - ${format.format(first.addDays(6))}';
  }

  @override
  Widget build(BuildContext context) {
    final express = style == 2;
    final locale = Localizations.localeOf(context).toString();
    final labels = WeekdayLabels.shortFrom(
      Localizations.localeOf(context).languageCode,
      first.weekday,
    );
    final days = [for (var i = 0; i < 7; i++) first.addDays(i)];
    final tallies = TimelineWeekStrip.tallies(habits, first);
    final done = tallies.fold(0, (sum, tally) => sum + tally.done);
    final due = tallies.fold(0, (sum, tally) => sum + tally.due);
    final muted = context.tokens.muted;
    final key = ValueKey(first.epochDay);

    final week = Row(
      key: key,
      children: [
        for (final (i, day) in days.indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _DayCard(
                day: day,
                label: labels[i].replaceAll('.', ''),
                selected: day.isSameDay(selected),
                tally: tallies[i],
                style: style,
                onTap: onSelected,
              ),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 0, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _range(locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
                if (due > 0) ...[
                  Icon(LucideIcons.circleCheck, size: 14, color: muted),
                  const SizedBox(width: 5),
                  Text(
                    '$done/$due',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                _Arrow(
                  icon: LucideIcons.chevronLeft,
                  tooltip: context.l10n.a11y_previous_week,
                  express: express,
                  onPressed: () => onShift(-1),
                ),
                const SizedBox(width: 6),
                _Arrow(
                  icon: LucideIcons.chevronRight,
                  tooltip: context.l10n.a11y_next_week,
                  express: express,
                  onPressed: () => onShift(1),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: express
                ? (details) =>
                    onShift((details.primaryVelocity ?? 0) < 0 ? 1 : -1)
                : null,
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final shift = child.key == key ? direction : -direction;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(0.25 * shift, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: week,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.tooltip,
    required this.express,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool express;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    final fill = context.colors.surfaceContainerHighest.withValues(alpha: 0.55);
    if (express) {
      return ExpressIconButton(
        icon: icon,
        size: 34,
        tint: muted,
        background: fill,
        tooltip: tooltip,
        onPressed: onPressed,
      );
    }
    return SizedBox.square(
      dimension: 34,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(backgroundColor: fill),
        icon: Icon(icon, size: 18, color: muted),
        onPressed: onPressed,
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.label,
    required this.selected,
    required this.tally,
    required this.style,
    required this.onTap,
  });

  final DateTime day;
  final String label;
  final bool selected;
  final DayTally tally;
  final int style;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final express = style == 2;
    final minimal = style == 1;
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final today = day.isSameDay(AppClock.today());
    final strong = minimal ? scheme.onSurface : scheme.primary;
    final ink = selected
        ? (minimal ? scheme.surface : scheme.onPrimary)
        : today
            ? strong
            : scheme.onSurface;
    final soft = selected ? ink.withValues(alpha: 0.75) : muted;
    final radius = express ? (selected ? 24.0 : 16.0) : 16.0;

    return Semantics(
      button: true,
      selected: selected,
      label: DateFormat.MMMMEEEEd(Localizations.localeOf(context).toString())
          .format(day),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onTap(day),
        child: AnimatedContainer(
          duration: express ? Express.morph : const Duration(milliseconds: 220),
          curve: express ? Express.bouncy : Curves.easeOutCubic,
          height: 80,
          decoration: BoxDecoration(
            color: selected
                ? strong
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: today && !selected
                  ? strong.withValues(alpha: 0.7)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: express
                      ? ExpressType.body.at(11, weight: 800, height: 1.1, color: soft)
                      : minimal
                          ? MinimalType.label(size: 11, color: soft)
                          : TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              color: soft,
                            ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  maxLines: 1,
                  style: express
                      ? ExpressType.display.at(
                          21,
                          height: 1.05,
                          color: ink,
                          tabular: true,
                        )
                      : minimal
                          ? MinimalType.figure(21, height: 1.05, color: ink)
                          : TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              color: ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                ),
                const SizedBox(height: 4),
                _DayMeter(
                  tally: tally,
                  color: selected ? ink : strong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayMeter extends StatelessWidget {
  const _DayMeter({required this.tally, required this.color});

  final DayTally tally;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (tally.due == 0) return const SizedBox(height: 14);
    if (tally.done == tally.due) {
      return Icon(LucideIcons.circleCheck, size: 14, color: color);
    }
    return Container(
      width: 24,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: ColoredBox(
          color: color.withValues(alpha: 0.2),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: tally.done / tally.due),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, fraction, _) => FractionallySizedBox(
                widthFactor: fraction,
                heightFactor: 1,
                child: ColoredBox(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
