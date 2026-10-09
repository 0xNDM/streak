import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/focus/data/focus_session.dart';

enum FocusRange { week, month, year }

class FocusMilestone {
  const FocusMilestone({
    required this.id,
    required this.title,
    required this.target,
    required this.progress,
    required this.unit,
    required this.icon,
  });

  final String id;
  final String title;
  final int target;
  final int progress;
  final String unit;
  final IconData icon;

  bool get isUnlocked => progress >= target;
  double get percentage => target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
}

@immutable
class FocusStats {
  const FocusStats({
    required this.todaySeconds,
    required this.weekSeconds,
    required this.previousWeekSeconds,
    required this.monthSeconds,
    required this.totalSeconds,
    required this.sessionCount,
    required this.longestSessionSeconds,
    required this.longestDaySeconds,
    required this.longestDayDate,
    required this.currentStreak,
    required this.longestStreak,
    required this.buckets,
    required this.series,
    required this.perHabit,
    required this.rangeCount,
    this.perLabel = const {},
    required this.productiveWindow,
    required this.milestones,
  });

  final int todaySeconds;
  final int weekSeconds;
  final int previousWeekSeconds;
  final int monthSeconds;
  final int totalSeconds;
  final int sessionCount;
  final int longestSessionSeconds;
  final int longestDaySeconds;
  final DateTime? longestDayDate;
  final int currentStreak;
  final int longestStreak;
  final List<DateTime> buckets;
  final List<int> series;
  final Map<String, int> perHabit;
  final Map<String, int> perLabel;
  final int rangeCount;
  final ({String title, IconData icon, int seconds, double percentage}) productiveWindow;
  final List<FocusMilestone> milestones;

  double get weeklyChangePercent {
    if (previousWeekSeconds == 0) return weekSeconds > 0 ? 100.0 : 0.0;
    return ((weekSeconds - previousWeekSeconds) / previousWeekSeconds) * 100.0;
  }

  List<MapEntry<String, int>> get labelRanking =>
      (perLabel.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(8)
          .toList();

  int get averageSeconds =>
      sessionCount == 0 ? 0 : totalSeconds ~/ sessionCount;

  int get rangeSeconds => series.fold(0, (sum, value) => sum + value);

  int get bestBucket {
    var best = 0;
    for (var i = 1; i < series.length; i++) {
      if (series[i] > series[best]) best = i;
    }
    return best;
  }

  static List<DateTime> _bucketsFor(
    FocusRange range,
    DateTime today,
    int weekStart,
    int offset,
  ) {
    switch (range) {
      case FocusRange.week:
        final first = today.startOfWeek(weekStart).addDays(offset * 7);
        return [for (var i = 0; i < 7; i++) first.addDays(i)];
      case FocusRange.month:
        final anchor = DateTime(today.year, today.month + offset);
        final days = DateTime(anchor.year, anchor.month + 1, 0).day;
        return [
          for (var i = 1; i <= days; i++)
            DateTime(anchor.year, anchor.month, i),
        ];
      case FocusRange.year:
        final year = today.year + offset;
        return [for (var m = 1; m <= 12; m++) DateTime(year, m)];
    }
  }

  static FocusStats compute({
    required List<FocusSession> sessions,
    required FocusRange range,
    required DateTime now,
    required int weekStart,
    String? habitId,
    int offset = 0,
  }) {
    final scoped = habitId == null
        ? sessions
        : sessions.where((s) => s.habitId == habitId).toList();

    final today =
        now.subtract(Duration(hours: AppClock.cutoffHour)).atMidnight;
    final weekFrom = today.startOfWeek(weekStart);
    final buckets = _bucketsFor(range, today, weekStart, offset);
    final series = List<int>.filled(buckets.length, 0);
    final perHabit = <String, int>{};
    final perLabel = <String, int>{};

    final todayIndex = today.epochDay;
    final weekIndex = weekFrom.epochDay;
    final firstBucket = buckets.first.epochDay;
    final bucketYear = buckets.first.year;

    var rangeCount = 0;
    var todaySeconds = 0;
    var weekSeconds = 0;
    var previousWeekSeconds = 0;
    var monthSeconds = 0;
    var totalSeconds = 0;
    var longestSession = 0;

    final perDayMap = <int, int>{};
    final perDayDateMap = <int, DateTime>{};

    // Productive hours buckets
    var morningSec = 0;
    var afternoonSec = 0;
    var eveningSec = 0;
    var nightSec = 0;

    for (final session in scoped) {
      final day = session.countedOn;
      final epoch = day.epochDay;
      final sec = session.seconds;
      totalSeconds += sec;
      if (sec > longestSession) longestSession = sec;

      // Accumulate per day
      perDayMap[epoch] = (perDayMap[epoch] ?? 0) + sec;
      perDayDateMap[epoch] ??= day;

      if (epoch == todayIndex) todaySeconds += sec;
      final weekOffset = epoch - weekIndex;
      if (weekOffset >= 0 && weekOffset < 7) weekSeconds += sec;
      if (weekOffset >= -7 && weekOffset < 0) previousWeekSeconds += sec;

      if (day.year == today.year && day.month == today.month) {
        monthSeconds += sec;
      }

      // Time of day calculation
      final hour = session.startedAt.hour;
      if (hour >= 6 && hour < 12) {
        morningSec += sec;
      } else if (hour >= 12 && hour < 17) {
        afternoonSec += sec;
      } else if (hour >= 17 && hour < 22) {
        eveningSec += sec;
      } else {
        nightSec += sec;
      }

      final index = range == FocusRange.year
          ? (day.year == bucketYear ? day.month - 1 : -1)
          : epoch - firstBucket;
      if (index >= 0 && index < buckets.length) {
        rangeCount++;
        series[index] += sec;
      }

      perHabit[session.habitId] =
          (perHabit[session.habitId] ?? 0) + sec;

      final sessionTags = session.tags.isNotEmpty
          ? session.tags
          : (session.label.isNotEmpty ? [session.label] : const <String>[]);

      for (final tag in sessionTags) {
        if (tag.isNotEmpty) {
          perLabel[tag] = (perLabel[tag] ?? 0) + sec;
        }
      }
    }

    // Longest day
    var longestDaySec = 0;
    DateTime? longestDayDate;
    perDayMap.forEach((epoch, sec) {
      if (sec > longestDaySec) {
        longestDaySec = sec;
        longestDayDate = perDayDateMap[epoch];
      }
    });

    // Streaks calculation
    final sortedDays = perDayMap.keys.toList()..sort();
    var currentStreak = 0;
    var longestStreak = 0;
    if (sortedDays.isNotEmpty) {
      var running = 0;
      int? prev;
      for (final d in sortedDays) {
        if (prev != null && d == prev + 1) {
          running++;
        } else {
          running = 1;
        }
        if (running > longestStreak) longestStreak = running;
        prev = d;
      }

      // Current streak: check if today or yesterday is the last active day
      final lastDay = sortedDays.last;
      if (lastDay == todayIndex || lastDay == todayIndex - 1) {
        var streakCounter = 0;
        var check = lastDay;
        while (perDayMap.containsKey(check)) {
          streakCounter++;
          check--;
        }
        currentStreak = streakCounter;
      }
    }

    // Determine Most Productive Time Window
    final maxSec = [morningSec, afternoonSec, eveningSec, nightSec].reduce((a, b) => a > b ? a : b);
    final ({String title, IconData icon, int seconds, double percentage}) productiveWindow;
    if (maxSec == 0) {
      productiveWindow = (
        title: 'Morning (9 AM - 12 PM)',
        icon: LucideIcons.sun,
        seconds: 0,
        percentage: 0.0,
      );
    } else if (maxSec == morningSec) {
      productiveWindow = (
        title: 'Morning (6 AM - 12 PM)',
        icon: LucideIcons.sunrise,
        seconds: morningSec,
        percentage: totalSeconds == 0 ? 0.0 : morningSec / totalSeconds,
      );
    } else if (maxSec == afternoonSec) {
      productiveWindow = (
        title: 'Afternoon (12 PM - 5 PM)',
        icon: LucideIcons.sun,
        seconds: afternoonSec,
        percentage: totalSeconds == 0 ? 0.0 : afternoonSec / totalSeconds,
      );
    } else if (maxSec == eveningSec) {
      productiveWindow = (
        title: 'Evening (5 PM - 10 PM)',
        icon: LucideIcons.sunset,
        seconds: eveningSec,
        percentage: totalSeconds == 0 ? 0.0 : eveningSec / totalSeconds,
      );
    } else {
      productiveWindow = (
        title: 'Night (10 PM - 6 AM)',
        icon: LucideIcons.moon,
        seconds: nightSec,
        percentage: totalSeconds == 0 ? 0.0 : nightSec / totalSeconds,
      );
    }

    // Milestones
    final totalHours = totalSeconds ~/ 3600;
    final milestones = [
      FocusMilestone(
        id: 'first_session',
        title: 'First Lock-In',
        target: 1,
        progress: scoped.length,
        unit: 'session',
        icon: LucideIcons.zap,
      ),
      FocusMilestone(
        id: 'streak_3',
        title: '3-Day Streak',
        target: 3,
        progress: longestStreak,
        unit: 'days',
        icon: LucideIcons.flame,
      ),
      FocusMilestone(
        id: 'streak_7',
        title: '7-Day Streak',
        target: 7,
        progress: longestStreak,
        unit: 'days',
        icon: LucideIcons.sparkles,
      ),
      FocusMilestone(
        id: 'hours_10',
        title: '10 Focused Hours',
        target: 10,
        progress: totalHours,
        unit: 'hours',
        icon: LucideIcons.clock,
      ),
      FocusMilestone(
        id: 'hours_50',
        title: '50 Focused Hours',
        target: 50,
        progress: totalHours,
        unit: 'hours',
        icon: LucideIcons.award,
      ),
      FocusMilestone(
        id: 'marathon',
        title: 'Deep Work Marathon',
        target: 60,
        progress: longestSession ~/ 60,
        unit: 'min',
        icon: LucideIcons.medal,
      ),
    ];

    return FocusStats(
      todaySeconds: todaySeconds,
      weekSeconds: weekSeconds,
      previousWeekSeconds: previousWeekSeconds,
      monthSeconds: monthSeconds,
      totalSeconds: totalSeconds,
      sessionCount: scoped.length,
      longestSessionSeconds: longestSession,
      longestDaySeconds: longestDaySec,
      longestDayDate: longestDayDate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      buckets: buckets,
      series: series,
      perHabit: perHabit,
      perLabel: perLabel,
      rangeCount: rangeCount,
      productiveWindow: productiveWindow,
      milestones: milestones,
    );
  }
}
