import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/date_labels.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/data/focus_stats.dart';
import 'package:streak/features/settings/state/settings_controller.dart';
import 'package:streak/features/statistics/widgets/stat_charts.dart';

class FocusRangeBars extends StatelessWidget {
  const FocusRangeBars({
    super.key,
    required this.stats,
    required this.range,
    required this.color,
    this.height = 150,
    this.onBarTap,
  });

  final FocusStats stats;
  final FocusRange range;
  final Color color;
  final double height;
  final void Function(DateTime start, DateTime end, String title)? onBarTap;

  double get _barWidth => switch (range) {
    FocusRange.week => 24,
    FocusRange.month => 26,
    FocusRange.year => 20,
  };

  void _handleBarTap(int index) {
    if (onBarTap == null || index < 0 || index >= stats.buckets.length) return;
    final bucket = stats.buckets[index];
    DateTime start;
    DateTime end;
    String title;

    switch (range) {
      case FocusRange.week:
        start = bucket.atMidnight;
        end = start.addDays(1).subtract(const Duration(milliseconds: 1));
        title = DateFormat('EEEE, MMM d, y').format(start);
      case FocusRange.month:
        start = bucket.atMidnight;
        end = start.addDays(7).subtract(const Duration(milliseconds: 1));
        final endDisplay = start.addDays(6);
        title = '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, y').format(endDisplay)}';
      case FocusRange.year:
        start = DateTime(bucket.year, bucket.month, 1).atMidnight;
        final next = DateTime(bucket.year, bucket.month + 1, 1).atMidnight;
        end = next.subtract(const Duration(milliseconds: 1));
        title = DateFormat('MMMM y').format(start);
    }

    onBarTap!(start, end, title);
  }

  String _label(BuildContext context, int index) {
    if (index < 0 || index >= stats.buckets.length) return '';
    final locale = Localizations.localeOf(context);
    switch (range) {
      case FocusRange.week:
        return WeekdayLabels.narrowFrom(
          locale.languageCode,
          context.read<SettingsController>().weekStart,
        )[index];
      case FocusRange.month:
        return 'W${index + 1}';
      case FocusRange.year:
        return index.isEven
            ? DateFormat.MMM(locale.toString()).format(stats.buckets[index])
            : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueBars(
      key: ValueKey(range),
      values: [for (final seconds in stats.series) seconds / 60],
      color: color,
      height: height,
      barWidth: _barWidth,
      label: (index) => _label(context, index),
      tooltip: (value) => formatHoursShort((value * 60).round()),
      axisFormat: (value) =>
          value <= 0 ? '0' : formatHoursShort((value * 60).round()),
      onBarTap: onBarTap != null ? _handleBarTap : null,
    );
  }
}
