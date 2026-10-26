import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/features/focus/state/focus_controller.dart';

class FocusDashboardHeader extends StatelessWidget {
  const FocusDashboardHeader({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final stats = context.select<
        FocusController,
        ({
          int totalSeconds,
          int activeDays,
          int elapsedDays,
          int streak,
        })>((focus) => (
          totalSeconds: focus.totalSeconds,
          activeDays: focus.totalActiveDaysCount,
          elapsedDays: focus.totalElapsedDaysSinceStart,
          streak: focus.currentStreak,
        ));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = context.colors;

    final totalHours = stats.totalSeconds ~/ 3600;
    final activeDaysLabel = stats.elapsedDays <= 0
        ? '${stats.activeDays}'
        : '${stats.activeDays}/${stats.elapsedDays}';

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.6 : 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 1. Locked-in (Total Hours)
          Expanded(
            child: _StatItem(
              value: '${totalHours}h',
              icon: LucideIcons.zap,
              iconColor: const Color(0xFFFBBF24), // Electric Amber
              label: context.l10n.focus_locked_in,
            ),
          ),
          const SizedBox(width: 20),
          // 2. Active Days (xx/xx)
          Expanded(
            child: _StatItem(
              value: activeDaysLabel,
              label: context.l10n.focus_active_days,
            ),
          ),
          const SizedBox(width: 20),
          // 3. Day Streak (xx 🔥)
          Expanded(
            child: _StatItem(
              value: '${stats.streak}',
              icon: LucideIcons.flame,
              iconColor: const Color(0xFFFF4D4F), // Vibrant Coral Red
              label: context.l10n.focus_day_streak,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    this.icon,
    this.iconColor,
    required this.label,
  });

  final String value;
  final IconData? icon;
  final Color? iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numberColor = isDark ? Colors.white : context.colors.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: numberColor,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(
                  icon,
                  size: 22,
                  color: iconColor,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: context.tokens.muted,
          ),
        ),
      ],
    );
  }
}
