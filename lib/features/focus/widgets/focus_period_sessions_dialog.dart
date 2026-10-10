import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/widgets/app_empty_state.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_widgets.dart';
import 'package:streak/features/habits/state/habits_controller.dart';

Future<void> showPeriodSessionsDialog({
  required BuildContext context,
  required String title,
  required DateTime start,
  required DateTime end,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogCtx) => _PeriodSessionsDialog(
      title: title,
      start: start,
      end: end,
    ),
  );
}

class _PeriodSessionsDialog extends StatelessWidget {
  const _PeriodSessionsDialog({
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final focus = context.watch<FocusController>();
    final habits = context.watch<HabitsController>();

    final periodSessions = focus.sessions.where((s) {
      final date = s.countedOn;
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final totalSeconds =
        periodSessions.fold<int>(0, (sum, s) => sum + s.seconds);

    return Dialog(
      backgroundColor: scheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 700,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(LucideIcons.calendar, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.5,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (totalSeconds > 0)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    formatHoursShort(totalSeconds),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
            ],
            centerTitle: false,
          ),
          body: periodSessions.isEmpty
              ? const Center(
                  child: AppEmptyState(
                    icon: LucideIcons.timer,
                    title: 'No Focus Sessions',
                    message:
                        'No focus sessions were recorded during this period.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  itemCount: periodSessions.length,
                  itemBuilder: (context, index) {
                    final session = periodSessions[index];
                    return FocusSessionCard(
                      session: session,
                      habit: session.habitId.isEmpty
                          ? null
                          : habits.byId(session.habitId),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
