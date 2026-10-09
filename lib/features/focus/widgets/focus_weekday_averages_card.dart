import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/date_labels.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';
import 'package:streak/features/statistics/widgets/stat_charts.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';

class FocusWeekdayAveragesCard extends StatefulWidget {
  const FocusWeekdayAveragesCard({
    super.key,
    required this.focus,
    this.weekStart = 1,
    required this.accent,
  });

  final FocusController focus;
  final int weekStart;
  final Color accent;

  @override
  State<FocusWeekdayAveragesCard> createState() => _FocusWeekdayAveragesCardState();
}

class _FocusWeekdayAveragesCardState extends State<FocusWeekdayAveragesCard> {
  int _subTab = 0; // 0 = Day of Week, 1 = Monthly

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final locale = Localizations.localeOf(context);
    final weekdayAverages = widget.focus.weekdayAverageSeconds;
    final monthlyTotals = widget.focus.monthlyTotalSeconds;

    // Weekday order starting from weekStart
    final orderedWeekdays = <int>[];
    for (var i = 0; i < 7; i++) {
      var w = (widget.weekStart + i);
      if (w > 7) w -= 7;
      orderedWeekdays.add(w);
    }

    final weekdayLabels = WeekdayLabels.narrowFrom(
      locale.languageCode,
      widget.weekStart,
    );

    // Find max weekday average
    var maxWeekdayAvg = 0.0;
    var bestWeekday = 1;
    for (final entry in weekdayAverages.entries) {
      if (entry.value > maxWeekdayAvg) {
        maxWeekdayAvg = entry.value;
        bestWeekday = entry.key;
      }
    }

    final weekdayNames = [
      '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    // Find max monthly total
    var maxMonthSec = 0;
    for (final val in monthlyTotals.values) {
      if (val > maxMonthSec) maxMonthSec = val;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.calendarDays,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _subTab == 0 ? 'Day of Week Averages' : 'Monthly Performance',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _subTab == 0
                            ? (maxWeekdayAvg > 0
                                ? 'Peak: ${weekdayNames[bestWeekday]}'
                                : 'All-time average since start')
                            : 'Focus totals over past months',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.tokens.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Segmented(
                options: const ['Weekday', 'Monthly'],
                index: _subTab,
                onChanged: (i) => setState(() => _subTab = i),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_subTab == 0) ...[
            // Weekday bars
            LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = ((constraints.maxWidth - 48) / 7).clamp(18.0, 36.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      final weekday = orderedWeekdays[i];
                      final avgSec = weekdayAverages[weekday] ?? 0.0;
                      final factor = maxWeekdayAvg > 0 ? (avgSec / maxWeekdayAvg).clamp(0.05, 1.0) : 0.05;
                      final isBest = maxWeekdayAvg > 0 && weekday == bestWeekday;

                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            avgSec > 0 ? formatHoursShort(avgSec.round()) : '—',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isBest ? FontWeight.w800 : FontWeight.w600,
                              color: isBest ? const Color(0xFF10B981) : context.tokens.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: barWidth,
                            height: 110 * factor,
                            decoration: BoxDecoration(
                              color: avgSec > 0
                                  ? (isBest ? const Color(0xFF10B981) : const Color(0xFF059669))
                                  : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            weekdayLabels[i],
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isBest ? FontWeight.w800 : FontWeight.w600,
                              color: isBest ? scheme.onSurface : context.tokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ] else ...[
            // Monthly view
            Column(
              children: [
                for (final entry in monthlyTotals.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 65,
                          child: Text(
                            DateFormat('MMM y').format(DateTime.parse('${entry.key}-01')),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                Container(
                                  height: 14,
                                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                ),
                                FractionallySizedBox(
                                  widthFactor: maxMonthSec > 0
                                      ? (entry.value / maxMonthSec).clamp(0.0, 1.0)
                                      : 0.0,
                                  child: Container(
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          child: Text(
                            entry.value > 0 ? formatHoursShort(entry.value) : '0h',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
