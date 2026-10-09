import 'package:flutter/material.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/habits/pages/habit_form_page.dart';

Future<void> showHabitFormDialog(
  BuildContext context, {
  Habit? habit,
  Habit? template,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = dialogContext.colors;
      return Dialog(
        backgroundColor: scheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 680,
            maxHeight: 880,
          ),
          child: HabitFormPage(habit: habit, template: template),
        ),
      );
    },
  );
}
