import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/settings/widgets/settings_rows.dart';
import 'package:streak/features/statistics/widgets/stat_charts.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';

class FocusTimeOfDayCard extends StatefulWidget {
  const FocusTimeOfDayCard({
    super.key,
    required this.focus,
    this.weekStart = 1,
    required this.accent,
  });

  final FocusController focus;
  final int weekStart;
  final Color accent;

  @override
  State<FocusTimeOfDayCard> createState() => _FocusTimeOfDayCardState();
}

class _FocusTimeOfDayCardState extends State<FocusTimeOfDayCard> {
  bool _isWeekly = true; // true = Weekly, false = Monthly

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final now = AppClock.now();
    final breakdown = widget.focus.timeOfDayBreakdown(
      isWeekly: _isWeekly,
      now: now,
      weekStart: widget.weekStart,
    );

    final total = breakdown.totalSec;
    final morningPct = total > 0 ? breakdown.morningSec / total : 0.0;
    final afternoonPct = total > 0 ? breakdown.afternoonSec / total : 0.0;
    final eveningPct = total > 0 ? breakdown.eveningSec / total : 0.0;
    final nightPct = total > 0 ? breakdown.nightSec / total : 0.0;

    final periods = [
      (
        title: context.l10n.focus_morning,
        timeWindow: '04:00 – 11:00',
        icon: LucideIcons.sunrise,
        seconds: breakdown.morningSec,
        pct: morningPct,
        color: const Color(0xFF10B981), // Emerald
      ),
      (
        title: context.l10n.focus_afternoon,
        timeWindow: '11:00 – 17:00',
        icon: LucideIcons.sun,
        seconds: breakdown.afternoonSec,
        pct: afternoonPct,
        color: const Color(0xFF34D399), // Mint
      ),
      (
        title: context.l10n.focus_evening,
        timeWindow: '17:00 – 22:00',
        icon: LucideIcons.sunset,
        seconds: breakdown.eveningSec,
        pct: eveningPct,
        color: const Color(0xFF059669), // Forest
      ),
      (
        title: context.l10n.focus_night,
        timeWindow: '22:00 – 04:00',
        icon: LucideIcons.moon,
        seconds: breakdown.nightSec,
        pct: nightPct,
        color: const Color(0xFF047857), // Dark Emerald
      ),
    ];

    // Find peak period with highest seconds
    var peakIndex = 0;
    var maxSeconds = periods[0].seconds;
    for (var i = 1; i < periods.length; i++) {
      if (periods[i].seconds > maxSeconds) {
        maxSeconds = periods[i].seconds;
        peakIndex = i;
      }
    }

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
                      LucideIcons.clock,
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
                          context.l10n.focus_time_of_day_breakdown,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _isWeekly
                              ? context.l10n.focus_this_week_local
                              : context.l10n.focus_this_month_local,
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
                options: [context.l10n.week, context.l10n.month],
                index: _isWeekly ? 0 : 1,
                onChanged: (i) => setState(() => _isWeekly = i == 0),
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
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _isWeekly
                      ? context.l10n.focus_no_focus_week
                      : context.l10n.focus_no_focus_month,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokens.muted,
                  ),
                ),
              ),
            )
          else ...[
            for (final (idx, p) in periods.indexed) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(p.icon, size: 16, color: p.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '(${p.timeWindow})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.tokens.muted,
                                  ),
                                ),
                              ),
                              if (maxSeconds > 0 && idx == peakIndex) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.sparkles,
                                          size: 10,
                                          color: Color(0xFF10B981)),
                                      const SizedBox(width: 3),
                                      Text(
                                        context.l10n.focus_peak,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatHoursShort(p.seconds),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${(p.pct * 100).toStringAsFixed(0)}%',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.tokens.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          ),
                          FractionallySizedBox(
                            widthFactor: p.pct.clamp(0.0, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: p.color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
