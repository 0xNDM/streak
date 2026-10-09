import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/utils/app_snackbar.dart';
import 'package:streak/core/widgets/app_confirm_dialog.dart';
import 'package:streak/core/widgets/app_empty_state.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_actions.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_dashboard_widgets.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';

Future<void> showFocusHistoryDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = dialogContext.colors;
      return Dialog(
        backgroundColor: scheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 680,
            maxHeight: 840,
          ),
          child: const FocusHistoryView(),
        ),
      );
    },
  );
}

class FocusHistoryView extends StatefulWidget {
  const FocusHistoryView({super.key});

  @override
  State<FocusHistoryView> createState() => _FocusHistoryViewState();
}

class _FocusHistoryViewState extends State<FocusHistoryView> {
  Future<void> _deleteSession(BuildContext context, FocusSession session) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.focus_delete_sessions,
      message: context.l10n.focus_delete_sessions_body(1),
      confirmLabel: context.l10n.delete,
    );
    if (confirmed != true || !context.mounted) return;

    final focus = context.read<FocusController>();
    final habits = context.read<HabitsController>();
    await countFocusTime(habits, focus, session, undo: true);
    await focus.removeSessions({session.id});
    if (!context.mounted) return;
    AppSnackbar.success(context, context.l10n.focus_sessions_deleted(1));
  }

  String _dateHeader(DateTime date, DateTime today, DateTime yesterday) {
    if (date.dayKey == today.dayKey) return 'Today';
    if (date.dayKey == yesterday.dayKey) return 'Yesterday';
    return DateFormat('EEEE, MMM d, y').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final focus = context.watch<FocusController>();
    final habits = context.watch<HabitsController>();
    final sessions = focus.sessions.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final today = AppClock.now().atMidnight;
    final yesterday = today.subtract(const Duration(days: 1)).atMidnight;

    // Group sessions by date
    final grouped = <String, List<FocusSession>>{};
    final groupDate = <String, DateTime>{};
    for (final s in sessions) {
      final key = s.countedOn.dayKey;
      grouped.putIfAbsent(key, () => []).add(s);
      groupDate.putIfAbsent(key, () => s.countedOn);
    }

    final sortedKeys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(LucideIcons.history, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Focus History',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${sessions.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.tokens.muted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.x, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: false,
      ),
      body: sessions.isEmpty
          ? Center(
              child: AppEmptyState(
                icon: LucideIcons.timer,
                title: 'No Focus Sessions Yet',
                message: 'Your completed focus sessions will appear here grouped by date.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final key = sortedKeys[index];
                final date = groupDate[key]!;
                final groupSessions = grouped[key]!;
                final totalDaySeconds = groupSessions.fold(0, (sum, s) => sum + s.seconds);
                final headerText = _dateHeader(date, today, yesterday);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              headerText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                formatHoursShort(totalDaySeconds),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final session in groupSessions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FocusSessionCard(
                            session: session,
                            habit: session.habitId.isEmpty
                                ? null
                                : habits.byId(session.habitId),
                            onDelete: () => _deleteSession(context, session),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
