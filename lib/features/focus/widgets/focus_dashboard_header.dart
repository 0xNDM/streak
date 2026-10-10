import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/features/focus/state/focus_controller.dart';

class FocusDashboardHeader extends StatelessWidget {
  const FocusDashboardHeader({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = context.colors;

    final totalHours = focus.totalSeconds ~/ 3600;
    final activeDays = focus.totalActiveDaysCount;
    final elapsedDays = focus.totalElapsedDaysSinceStart;
    final streak = focus.currentStreak;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131316)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // 1. Locked-in (Total Hours)
          Expanded(
            child: _StatItem(
              value: '${totalHours}h',
              icon: LucideIcons.zap,
              iconColor: const Color(0xFFFBBF24), // Electric Amber
              label: 'locked-in',
            ),
          ),
          Container(
            height: 38,
            width: 1,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          ),
          // 2. Active Days (xx/xx)
          Expanded(
            child: _StatItem(
              value: '$activeDays/$elapsedDays',
              label: 'active days',
            ),
          ),
          Container(
            height: 38,
            width: 1,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          ),
          // 3. Day Streak (xx 🔥)
          Expanded(
            child: _StatItem(
              value: '$streak',
              icon: LucideIcons.flame,
              iconColor: const Color(0xFFFF4D4F), // Vibrant Coral Red
              label: 'day streak',
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
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: numberColor,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 5),
              Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ],
          ],
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
