import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/date_labels.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_period_navigator.dart';
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
  State<FocusWeekdayAveragesCard> createState() =>
      _FocusWeekdayAveragesCardState();
}

class _FocusWeekdayAveragesCardState extends State<FocusWeekdayAveragesCard> {
  int _subTab = 0; // 0 = Month, 1 = All Time
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final locale = Localizations.localeOf(context);
    final now = AppClock.now();

    final weekdayAverages = _subTab == 0
        ? widget.focus.monthWeekdayAverageSeconds(offset: _offset, now: now)
        : widget.focus.weekdayAverageSeconds;

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
    final periodLabel = _subTab == 0
        ? formatMonthPeriod(context, _offset, now: now)
        : context.l10n.period_all_time;

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
                        Row(
                          children: [
                            Flexible(
                              child: FocusPeriodNavigator(
                                label: periodLabel,
                                offset: _offset,
                                resetLabel: _subTab == 0
                                    ? context.l10n.period_this_month
                                    : null,
                                showArrows: _subTab == 0,
                                onOffsetChanged: (val) =>
                                    setState(() => _offset = val),
                                accent: widget.accent,
                              ),
                            ),
                            if (maxWeekdayAvg > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${context.l10n.focus_peak_weekday(weekdayNameFormat.format(DateTime(2024, 1, bestWeekday)))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.tokens.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final segmented = Segmented(
                options: [
                  context.l10n.month,
                  context.l10n.period_all_time,
                ],
                index: _subTab,
                onChanged: (i) => setState(() {
                  _subTab = i;
                  _offset = 0;
                }),
              );

              if (constraints.maxWidth < 460) {
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
                  for (var i = 0; i < 7; i++) ...[
                    Builder(
                      builder: (context) {
                        final weekday = orderedWeekdays[i];
                        final avgSec = weekdayAverages[weekday] ?? 0.0;
                        final ratio = maxWeekdayAvg > 0
                            ? (avgSec / maxWeekdayAvg).clamp(0.0, 1.0)
                            : 0.0;
                        final isPeak =
                            maxWeekdayAvg > 0 && avgSec == maxWeekdayAvg;
                        final isZero = avgSec == 0;

                        final barColor = isZero
                            ? scheme.surfaceContainerHighest
                            : (isPeak
                                ? const Color(0xFF10B981)
                                : const Color(0xFF10B981)
                                    .withValues(alpha: 0.45));

                        final durationLabel = formatHoursShort(avgSec.round());
                        final dayName = weekdayNameFormat
                            .format(DateTime(2024, 1, weekday));

                        return Tooltip(
                          message: '$dayName: $durationLabel avg',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isZero ? '0' : durationLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isPeak
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isPeak
                                      ? const Color(0xFF10B981)
                                      : context.tokens.muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: barWidth,
                                height: 90,
                                alignment: Alignment.bottomCenter,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Container(
                                  width: barWidth,
                                  height: (90 * ratio).clamp(
                                    isZero ? 0.0 : 4.0,
                                    90.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                weekdayLabels[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isPeak
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isPeak
                                      ? const Color(0xFF10B981)
                                      : context.colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
