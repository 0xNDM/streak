import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/date_labels.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';

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
  int _subTab = 0; // 0 = All Time, 1 = This Month

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final locale = Localizations.localeOf(context);

    final weekdayAverages = _subTab == 0
        ? widget.focus.weekdayAverageSeconds
        : widget.focus.currentMonthWeekdayAverageSeconds;

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

    final weekdayNameFormat = DateFormat.EEEE(locale.toString());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Row(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.focus_day_of_week,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          maxWeekdayAvg > 0
                              ? context.l10n.focus_peak_weekday(
                                  weekdayNameFormat.format(
                                    DateTime(2024, 1, bestWeekday),
                                  ),
                                )
                              : (_subTab == 0
                                  ? context.l10n.focus_all_time_average
                                  : context.l10n.focus_month_average),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.tokens.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final segmented = Segmented(
                options: [
                  context.l10n.period_all_time,
                  context.l10n.focus_this_month,
                ],
                index: _subTab,
                onChanged: (i) => setState(() => _subTab = i),
              );

              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    segmented,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  segmented,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Weekday bars
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth =
                  ((constraints.maxWidth - 48) / 7).clamp(18.0, 36.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Builder(
                      builder: (context) {
                        final weekday = orderedWeekdays[i];
                        final avgSec = weekdayAverages[weekday] ?? 0.0;
                        final factor = maxWeekdayAvg > 0
                            ? (avgSec / maxWeekdayAvg).clamp(0.05, 1.0)
                            : 0.05;
                        final isBest =
                            maxWeekdayAvg > 0 && weekday == bestWeekday;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              avgSec > 0
                                  ? formatHoursShort(avgSec.round())
                                  : '—',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    isBest ? FontWeight.w800 : FontWeight.w600,
                                color: isBest
                                    ? const Color(0xFF10B981)
                                    : context.tokens.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: barWidth,
                              height: 110 * factor,
                              decoration: BoxDecoration(
                                color: avgSec > 0
                                    ? (isBest
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF059669))
                                    : scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              weekdayLabels[i],
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight:
                                    isBest ? FontWeight.w800 : FontWeight.w600,
                                color: isBest
                                    ? scheme.onSurface
                                    : context.tokens.muted,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
