import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_pill.dart';
import 'package:streak/features/settings/state/settings_controller.dart';

class MiniTimerChip extends StatelessWidget {
  const MiniTimerChip({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<SettingsController>().focusEnabled) {
      return const SizedBox.shrink();
    }

    final focus = context.watch<FocusController>();
    if (!focus.isActive) return const SizedBox.shrink();

    final running = focus.isRunning;
    final accent = context.colors.primary;
    final ink = running ? accent : context.tokens.warning;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        button: true,
        label: 'Focus timer',
        child: GestureDetector(
          onTap: () => openFocus(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 10,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: running
                  ? accent.withValues(alpha: 0.12)
                  : context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: running
                    ? accent.withValues(alpha: 0.45)
                    : context.colors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: compact
                ? Text(
                    formatDuration(focus.displaySeconds),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        running ? LucideIcons.timer : LucideIcons.pause,
                        size: 14,
                        color: ink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatDuration(focus.displaySeconds),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
