import 'package:flutter/material.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/widgets/keep_built.dart';
import 'package:streak/core/extensions/inset_extensions.dart';
import 'package:streak/core/widgets/pane_mark.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/habits/widgets/grid_habit_cards.dart';
import 'package:streak/features/habits/widgets/habit_entrance.dart';
import 'package:streak/features/habits/widgets/habit_heatmap.dart';
import 'package:streak/features/habits/widgets/slot_transition.dart';
import 'package:streak/features/habits/widgets/swipe_check.dart';

class MinimalHabitList extends StatelessWidget {
  const MinimalHabitList({
    super.key,
    required this.habits,
    required this.mode,
    required this.header,
    required this.onOpen,
    required this.onToggleToday,
    required this.onToggleDay,
    required this.onLongPress,
    this.onSwipe,
    this.leaving = const {},
  });

  static EdgeInsets _padding(BuildContext context) =>
      context.pagePadding(16, 8, 16, 104);

  final List<Habit> habits;
  final HeatmapMode mode;
  final Widget header;
  final ValueChanged<Habit> onOpen;
  final ValueChanged<Habit> onToggleToday;
  final void Function(Habit habit, DateTime date) onToggleDay;
  final ValueChanged<Habit> onLongPress;
  final ValueChanged<Habit>? onSwipe;
  final Set<String> leaving;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 560),
      reverseDuration: const Duration(milliseconds: 150),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => child.key == ValueKey(mode)
          ? _SwitchIn(animation: animation, child: child)
          : FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.98, end: 1.0).animate(animation),
                child: child,
              ),
            ),
      child: KeyedSubtree(
        key: ValueKey(mode),
        child: mode == HeatmapMode.month ? _monthGrid(context) : _list(context),
      ),
    );
  }

  Widget _list(BuildContext context) {
    return ListView.builder(
      padding: _padding(context),
      itemCount: habits.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _Cascade(index: 0, child: header);
        final i = index - 1;
        final habit = habits[i];
        return _Cascade(
          index: index,
          child: HabitEntrance(
          key: ValueKey(habit.id),
          index: i,
          child: SlotTransition(
            leaving: leaving.contains(habit.id),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PaneMark(
                id: habit.id,
                tint: habit.color,
                corners: BorderRadius.circular(20),
                child: SwipeCheck(
                  done: habit.isCompletedOn(AppClock.today()),
                  tint: habit.color,
                  corners: BorderRadius.circular(20),
                  onSwipe: onSwipe == null ? null : () => onSwipe!(habit),
                  child: KeepBuilt(
                  keys: [habit, mode, AppClock.today()],
                  build: () => mode == HeatmapMode.week
                    ? GridWeekCard(
                        habit: habit,
                        onOpen: () => onOpen(habit),
                        onToggleDay: (d) => onToggleDay(habit, d),
                        onLongPress: () => onLongPress(habit),
                      )
                    : GridYearCard(
                        habit: habit,
                        onOpen: () => onOpen(habit),
                        onToggleToday: () => onToggleToday(habit),
                        onToggleDay: (d) => onToggleDay(habit, d),
                        onLongPress: () => onLongPress(habit),
                      ),
                  ),
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _monthGrid(BuildContext context) {
    return ListView.builder(
      padding: _padding(context),
      itemCount: (habits.length + 1) ~/ 2 + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _Cascade(index: 0, child: header);
        final i = (index - 1) * 2;
        return _Cascade(
          index: index,
          child: HabitEntrance(
          key: ValueKey(habits[i].id),
          index: index - 1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _monthCard(habits[i])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < habits.length
                        ? _monthCard(habits[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _monthCard(Habit habit) {
    return PaneMark(
      id: habit.id,
      tint: habit.color,
      corners: BorderRadius.circular(30),
      child: SwipeCheck(
        done: habit.isCompletedOn(AppClock.today()),
        tint: habit.color,
        corners: BorderRadius.circular(30),
        onSwipe: onSwipe == null ? null : () => onSwipe!(habit),
        child: KeepBuilt(
        keys: [habit, AppClock.today()],
        build: () => GridMonthCard(
          habit: habit,
          onOpen: () => onOpen(habit),
          onToggleToday: () => onToggleToday(habit),
          onToggleDay: (d) => onToggleDay(habit, d),
          onLongPress: () => onLongPress(habit),
        ),
        ),
      ),
    );
  }
}

class _SwitchIn extends InheritedWidget {
  const _SwitchIn({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_SwitchIn old) => old.animation != animation;
}

class _Cascade extends StatelessWidget {
  const _Cascade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parent =
        context.dependOnInheritedWidgetOfExactType<_SwitchIn>()?.animation;
    if (parent == null) return child;
    final start = 0.1 + 0.07 * index.clamp(0, 7);
    final curve = CurvedAnimation(
      parent: parent,
      curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.16), end: Offset.zero)
            .animate(curve),
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(curve),
          child: child,
        ),
      ),
    );
  }
}
