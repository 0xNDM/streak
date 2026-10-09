import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/app_confirm_dialog.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_duration_fields.dart';

class FocusLabelPicker extends StatelessWidget {
  const FocusLabelPicker({
    super.key,
    required this.habitId,
    required this.selected,
    required this.onChanged,
  });

  static const maxLength = 30;

  final String habitId;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  Future<void> _add(BuildContext context) async {
    final picked = await showDialog<({String name, Color color})>(
      context: context,
      builder: (_) => const _NewLabelDialog(),
    );
    if (picked == null || !context.mounted) return;
    final name = picked.name.trim();
    if (name.isEmpty) return;
    await context.read<FocusController>().rememberLabel(habitId, name, color: picked.color);
    final updated = Set<String>.from(selected)..add(name);
    onChanged(updated);
  }

  Future<void> _forget(BuildContext context, String label) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.focus_label_remove,
      message: context.l10n.focus_label_remove_body(label),
      confirmLabel: context.l10n.focus_label_remove_confirm,
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<FocusController>().forgetLabel(habitId, label);
    if (selected.contains(label)) {
      final updated = Set<String>.from(selected)..remove(label);
      onChanged(updated);
    }
  }

  void _toggle(String label) {
    final updated = Set<String>.from(selected);
    if (updated.contains(label)) {
      updated.remove(label);
    } else {
      updated.add(label);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusController>();
    final labels = focus.labelsFor(habitId);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FocusChip(
          label: context.l10n.focus_label_none,
          selected: selected.isEmpty,
          onTap: () => onChanged(const {}),
        ),
        for (final label in labels)
          FocusChip(
            label: label,
            selected: selected.contains(label),
            color: focus.colorForLabel(label),
            onTap: () => _toggle(label),
            onLongPress: () => _forget(context, label),
          ),
        FocusChip(
          label: context.l10n.focus_label_new,
          icon: LucideIcons.plus,
          selected: false,
          onTap: () => _add(context),
        ),
      ],
    );
  }
}

class _NewLabelDialog extends StatefulWidget {
  const _NewLabelDialog();

  @override
  State<_NewLabelDialog> createState() => _NewLabelDialogState();
}

class _NewLabelDialogState extends State<_NewLabelDialog> {
  final _field = TextEditingController();
  Color _color = FocusController.defaultTagColors[0];

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _done() {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop((name: text, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.focus_label_new),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _field,
            autofocus: true,
            maxLength: FocusLabelPicker.maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: context.l10n.focus_label_hint,
              prefixIcon: Icon(LucideIcons.tag, color: _color, size: 20),
            ),
            onSubmitted: (_) => _done(),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.color,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in FocusController.defaultTagColors)
                GestureDetector(
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _color == color
                          ? Border.all(color: context.colors.onSurface, width: 2.2)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _done, child: Text(context.l10n.save)),
      ],
    );
  }
}
