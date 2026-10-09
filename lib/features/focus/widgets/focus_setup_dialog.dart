import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/icons/habit_glyph.dart';
import 'package:streak/core/routing/app_navigator.dart';
import 'package:streak/core/widgets/sheet_type.dart';
import 'package:streak/features/focus/pages/focus_page.dart';
import 'package:streak/features/focus/widgets/focus_duration_fields.dart';
import 'package:streak/features/focus/widgets/focus_label_picker.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/habits/state/habits_controller.dart';
import 'package:streak/features/settings/state/settings_controller.dart';

Future<void> showFocusSetupDialog(BuildContext context, {String? habitId}) {
  return showDialog<void>(
    context: context,
    builder: (_) => FocusSetupDialog(habitId: habitId),
  );
}

class FocusSetupDialog extends StatefulWidget {
  const FocusSetupDialog({super.key, this.habitId});

  final String? habitId;

  @override
  State<FocusSetupDialog> createState() => _FocusSetupDialogState();
}

class _FocusSetupDialogState extends State<FocusSetupDialog> {
  late String _habitId = widget.habitId ?? '';
  Set<String> _tags = {};
  int _minutes = 25;
  bool _pomodoro = false;
  int _breakMinutes = 5;
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final habit = context.read<HabitsController>().byId(_habitId);
    if (habit != null) return _pick(habit);
    final settings = context.read<SettingsController>();
    _minutes = settings.focusMinutes;
    _pomodoro = settings.focusBreakMinutes > 0;
    if (_pomodoro) _breakMinutes = settings.focusBreakMinutes;
  }

  void _pick(Habit habit) {
    _habitId = habit.id;
    _tags = {};
    _minutes = habit.focusMinutes;
    _pomodoro = habit.focusBreakMinutes > 0;
    if (_pomodoro) _breakMinutes = habit.focusBreakMinutes;
  }

  void _start() {
    final breakMinutes = _pomodoro ? _breakMinutes : 0;
    final habits = context.read<HabitsController>();
    final habit = habits.byId(_habitId);
    if (habit == null) {
      context.read<SettingsController>().rememberFocusSetup(_minutes, breakMinutes);
    } else if (habit.focusMinutes != _minutes || habit.focusBreakMinutes != breakMinutes) {
      habits.update(habit.copyWith(
        focusMinutes: _minutes,
        focusBreakMinutes: breakMinutes,
      ));
    }
    Navigator.of(context).pop();
    AppNavigator.push(
      FocusPage(
        startHabitId: _habitId,
        startMinutes: _minutes,
        breakMinutes: breakMinutes,
        startLabel: _tags.join(', '),
        startTags: _tags.toList(),
      ),
      fade: true,
      name: FocusPage.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final habits = context.watch<HabitsController>().habits;
    final habit = habits.where((h) => h.id == _habitId).firstOrNull;
    final accent = habit?.color ?? scheme.primary;

    return Dialog(
      backgroundColor: scheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.timer, color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.focus,
                        style: sheetTitleStyle(context, size: 20),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      context.l10n.focus_pick_habit,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(context.l10n.focus_free_session),
                            avatar: const Icon(LucideIcons.timer, size: 16),
                            selected: _habitId.isEmpty,
                            onSelected: (_) => setState(() => _habitId = ''),
                          ),
                          const SizedBox(width: 8),
                          for (final h in habits) ...[
                            ChoiceChip(
                              label: Text(h.name),
                              avatar: HabitGlyph(glyph: h.icon, color: h.color, size: 16),
                              selected: _habitId == h.id,
                              onSelected: (_) => setState(() => _pick(h)),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.focus_label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    FocusLabelPicker(
                      habitId: _habitId,
                      selected: _tags,
                      onChanged: (tags) => setState(() => _tags = tags),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.focus_duration,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    FocusDurationChips(
                      minutes: _minutes,
                      onChanged: (m) => setState(() => _minutes = m),
                    ),
                    if (_minutes > 0) ...[
                      const SizedBox(height: 18),
                      FocusPomodoroCard(
                        enabled: _pomodoro,
                        breakMinutes: _breakMinutes,
                        onToggle: (v) => setState(() => _pomodoro = v),
                        onBreakChanged: (v) => setState(() => _breakMinutes = v),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  icon: const Icon(LucideIcons.play, size: 18),
                  label: Text(
                    context.l10n.focus_start,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _start,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
