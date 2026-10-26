import 'package:flutter/foundation.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/focus/data/focus_session.dart';

enum FocusRange { week, month, year }

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
        final first = DateTime(anchor.year, anchor.month, 1)
            .startOfWeek(weekStart);
        final last = DateTime(anchor.year, anchor.month + 1, 0);
        final weekCount = ((last.epochDay - first.epochDay) ~/ 7) + 1;
        return [
          for (var i = 0; i < weekCount; i++) first.addDays(i * 7),
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
    final scopedSlices = [
      for (final session in scoped) ...session.slices(),
    ];

    final today = now.atMidnight;
    final weekFrom = today.startOfWeek(weekStart);
    final monthAnchor = DateTime(today.year, today.month + offset);
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

    for (final session in scoped) {
      totalSeconds += session.seconds;
      if (session.seconds > longestSession) longestSession = session.seconds;
    }

    for (final session in scopedSlices) {
      final day = session.countedOn;
      final epoch = day.epochDay;
      final sec = session.seconds;

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

      final int index;
      if (range == FocusRange.year) {
        index = (day.year == bucketYear ? day.month - 1 : -1);
      } else if (range == FocusRange.month) {
        if (day.year == monthAnchor.year &&
            day.month == monthAnchor.month) {
          index = ((day.startOfWeek(weekStart).epochDay - firstBucket) ~/ 7)
              .clamp(0, buckets.length - 1);
        } else {
          index = -1;
        }
      } else {
        index = epoch - firstBucket;
      }
      if (index >= 0 && index < buckets.length) {
        rangeCount++;
        series[index] += sec;
      }

      perHabit[session.habitId] =
          (perHabit[session.habitId] ?? 0) + sec;

      for (final labelId in session.labelIds) {
        if (labelId.isNotEmpty) {
          perLabel[labelId] = (perLabel[labelId] ?? 0) + sec;
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

    final streaks = focusStreaks(scopedSlices, now: now);

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
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
      buckets: buckets,
      series: series,
      perHabit: perHabit,
      perLabel: perLabel,
      rangeCount: rangeCount,
    );
  }
}
