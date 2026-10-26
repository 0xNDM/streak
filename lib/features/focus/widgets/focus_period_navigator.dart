import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';

String formatWeekPeriod(
  BuildContext context,
  int offset,
  int weekStart, {
  DateTime? now,
}) {
  if (offset == 0) return context.l10n.period_this_week;
  if (offset == -1) return context.l10n.period_last_week;
  final base = now ?? AppClock.now();
  final start = base.startOfWeek(weekStart).addDays(offset * 7);
  final end = start.addDays(6);
  final locale = Localizations.localeOf(context).toString();
  final fmt = DateFormat.MMMd(locale);
  final yearSuffix = start.year == base.year ? '' : ', ${start.year}';
  return '${fmt.format(start)} – ${fmt.format(end)}$yearSuffix';
}

String formatMonthPeriod(
  BuildContext context,
  int offset, {
  DateTime? now,
}) {
  if (offset == 0) return context.l10n.period_this_month;
  if (offset == -1) return context.l10n.period_last_month;
  final base = now ?? AppClock.now();
  final anchor = DateTime(base.year, base.month + offset);
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMM(locale).format(anchor);
}

class FocusPeriodNavigator extends StatelessWidget {
  const FocusPeriodNavigator({
    super.key,
    required this.label,
    required this.offset,
    required this.onOffsetChanged,
    this.resetLabel,
    this.showArrows = true,
    this.accent,
  });

  final String label;
  final int offset;
  final ValueChanged<int> onOffsetChanged;
  final String? resetLabel;
  final bool showArrows;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tint = accent ?? scheme.primary;

    if (!showArrows) {
      return Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: context.tokens.muted,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavArrow(
          icon: LucideIcons.chevronLeft,
          tooltip: context.l10n.a11y_previous_week,
          onTap: () => onOffsetChanged(offset - 1),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: offset == 0 ? context.tokens.muted : tint,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _NavArrow(
          icon: LucideIcons.chevronRight,
          tooltip: context.l10n.a11y_next_week,
          onTap: offset < 0 ? () => onOffsetChanged(offset + 1) : null,
        ),
        if (offset != 0 && resetLabel != null && resetLabel!.isNotEmpty) ...[
          const SizedBox(width: 14),
          Tooltip(
            message: resetLabel!,
            child: InkWell(
              onTap: () => onOffsetChanged(0),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: tint.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.rotateCcw, size: 10, color: tint),
                    const SizedBox(width: 4),
                    Text(
                      resetLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: enabled ? 0.9 : 0.25,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest.withValues(
                alpha: enabled ? 0.6 : 0.2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: context.colors.onSurface),
          ),
        ),
      ),
    );
  }
}
