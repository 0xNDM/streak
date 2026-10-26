import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/utils/app_snackbar.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/focus/state/focus_actions.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_label_picker.dart';
import 'package:streak/features/habits/state/habits_controller.dart';

class _SessionEdit {
  const _SessionEdit({required this.seconds, required this.labelIds});

  final int seconds;
  final List<String> labelIds;
}

Future<void> editFocusSession(
  BuildContext context,
  FocusSession session,
) async {
  final focus = context.read<FocusController>();
  final habits = context.read<HabitsController>();
  if (!focus.canEditSession(session)) {
    AppSnackbar.info(context, context.l10n.focus_edit_expired);
    return;
  }

  final edit = await showDialog<_SessionEdit>(
    context: context,
    builder: (_) => _SessionEditDialog(session: session),
  );
  if (edit == null || !context.mounted) return;

  final updated = await focus.editSession(
    id: session.id,
    seconds: edit.seconds,
    labelIds: edit.labelIds,
  );
  if (updated == null) {
    if (context.mounted) {
      AppSnackbar.error(context, context.l10n.focus_edit_expired);
    }
    return;
  }

  final habit = habits.byId(updated.habitId);
  if (habit != null &&
      habit.isTimeAmount &&
      updated.seconds != session.seconds) {
    await countFocusTime(habits, focus, session, undo: true);
    await countFocusTime(habits, focus, updated);
  }

  if (!context.mounted) return;
  AppSnackbar.success(context, context.l10n.focus_edit_saved);
}

class _SessionEditDialog extends StatefulWidget {
  const _SessionEditDialog({required this.session});

  final FocusSession session;

  @override
  State<_SessionEditDialog> createState() => _SessionEditDialogState();
}

class _SessionEditDialogState extends State<_SessionEditDialog> {
  late final TextEditingController _duration;
  late Set<String> _labelIds = widget.session.labelIds.toSet();
  int? _seconds;

  @override
  void initState() {
    super.initState();
    _seconds = widget.session.seconds;
    _duration = TextEditingController(
      text: _formatMinutes(widget.session.seconds),
    );
  }

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  String _formatMinutes(int seconds) {
    final minutes = seconds / 60;
    return minutes == minutes.roundToDouble()
        ? '${minutes.round()}'
        : minutes.toStringAsFixed(1);
  }

  void _onDurationChanged(String value) {
    final minutes = double.tryParse(value.replaceAll(',', '.').trim());
    setState(() {
      _seconds = minutes == null ? null : (minutes * 60).round();
    });
  }

  void _save() {
    final seconds = _seconds;
    if (seconds == null || seconds <= 0) return;
    Navigator.of(context).pop(
      _SessionEdit(seconds: seconds, labelIds: _labelIds.toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final end = widget.session.endedAt;
    final seconds = _seconds;
    final start = seconds == null || seconds <= 0
        ? null
        : end.subtract(Duration(seconds: seconds));
    final timeFormat = DateFormat.jm(locale);
    final valid = seconds != null && seconds > 0;

    return AlertDialog(
      title: Text(context.l10n.focus_edit_session),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _duration,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText:
                    '${context.l10n.focus_duration} (${context.l10n.unit_minutes})',
                errorText: valid ? null : context.l10n.focus_edit_invalid,
              ),
              onChanged: _onDurationChanged,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Text(
              start == null
                  ? timeFormat.format(end)
                  : '${timeFormat.format(start)} - ${timeFormat.format(end)}',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.focus_label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            FocusLabelPicker(
              selected: _labelIds,
              onChanged: (value) => setState(() => _labelIds = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: valid ? _save : null,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
