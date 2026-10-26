import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/app_confirm_dialog.dart';
import 'package:streak/features/focus/data/focus_label.dart';
import 'package:streak/features/focus/state/focus_controller.dart';
import 'package:streak/features/focus/widgets/focus_duration_fields.dart';

class FocusLabelPicker extends StatefulWidget {
  const FocusLabelPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const maxLength = 30;

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<FocusLabelPicker> createState() => _FocusLabelPickerState();
}

class _FocusLabelPickerState extends State<FocusLabelPicker> {
  final Set<String> _expanded = {};

  Future<void> _add(BuildContext context) async {
    final label = await showCreateOrEditLabelDialog(context);
    if (label == null || !context.mounted) return;
    final updated = Set<String>.from(widget.selected)..add(label.id);
    if (label.parentId != null) updated.remove(label.parentId);
    if (label.parentId != null) _expanded.add(label.parentId!);
    widget.onChanged(updated);
  }

  Future<void> _manageLabel(BuildContext context, FocusLabel label) async {
    final focus = context.read<FocusController>();
    final childIds = focus.childrenOf(label.id).map((child) => child.id).toSet();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: label.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      focus.labelDisplayName(label.id),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: Text(context.l10n.focus_label_edit),
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.archive),
              title: Text(context.l10n.focus_label_archive),
              onTap: () => Navigator.of(sheet).pop('archive'),
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: context.tokens.danger),
              title: Text(
                context.l10n.focus_label_delete,
                style: TextStyle(color: context.tokens.danger),
              ),
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == 'edit') {
      await showCreateOrEditLabelDialog(context, labelToEdit: label);
    } else if (action == 'archive') {
      await focus.archiveLabel(label.id);
      final ids = {label.id, ...childIds};
      widget.onChanged(
        Set<String>.from(widget.selected)..removeWhere(ids.contains),
      );
    } else if (action == 'delete') {
      final confirmed = await showAppConfirmDialog(
        context,
        title: context.l10n.focus_label_delete,
        message: context.l10n.focus_label_delete_body(
          focus.labelDisplayName(label.id),
        ),
        confirmLabel: context.l10n.delete,
      );
      if (confirmed != true || !context.mounted) return;
      final ids = {label.id, ...childIds};
      await focus.deleteLabelPermanently(label.id);
      widget.onChanged(
        Set<String>.from(widget.selected)..removeWhere(ids.contains),
      );
    }
  }

  void _toggle(FocusController focus, FocusLabel label) {
    final updated = Set<String>.from(widget.selected);
    if (updated.contains(label.id)) {
      updated.remove(label.id);
      if (!label.isChild) _expanded.remove(label.id);
    } else {
      if (label.parentId != null) {
        updated.remove(label.parentId);
        _expanded.add(label.parentId!);
      } else {
        for (final child in focus.childrenOf(label.id)) {
          updated.remove(child.id);
        }
        _expanded.add(label.id);
      }
      updated.add(label.id);
    }
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusController>();
    final labels = focus.labels;
    final parents = labels.where((label) => !label.isChild).toList();
    final parentIds = parents.map((label) => label.id).toSet();
    final orphans = labels
        .where((label) => label.isChild && !parentIds.contains(label.parentId))
        .toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FocusChip(
          label: context.l10n.focus_label_none,
          selected: widget.selected.isEmpty,
          onTap: () {
            _expanded.clear();
            widget.onChanged(const {});
          },
        ),
        for (final parent in parents) ...[
          FocusChip(
            label: parent.name,
            selected: widget.selected.contains(parent.id),
            color: parent.color,
            icon: focus.childrenOf(parent.id).isEmpty
                ? null
                : _expanded.contains(parent.id)
                    ? LucideIcons.chevronDown
                    : LucideIcons.chevronRight,
            onTap: () => _toggle(focus, parent),
            onLongPress: () => _manageLabel(context, parent),
          ),
          if (_expanded.contains(parent.id) ||
              widget.selected.contains(parent.id) ||
              focus.childrenOf(parent.id).any(
                    (child) => widget.selected.contains(child.id),
                  ))
            for (final child in focus.childrenOf(parent.id))
              FocusChip(
                label: focus.labelDisplayName(child.id),
                selected: widget.selected.contains(child.id),
                color: child.color,
                onTap: () => _toggle(focus, child),
                onLongPress: () => _manageLabel(context, child),
              ),
        ],
        for (final orphan in orphans)
          FocusChip(
            label: orphan.name,
            selected: widget.selected.contains(orphan.id),
            color: orphan.color,
            onTap: () => _toggle(focus, orphan),
            onLongPress: () => _manageLabel(context, orphan),
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

class _LabelDraft {
  const _LabelDraft(this.name, this.color, this.parentId);

  final String name;
  final Color color;
  final String? parentId;
}

Future<FocusLabel?> showCreateOrEditLabelDialog(
  BuildContext context, {
  FocusLabel? labelToEdit,
  String? preselectedParentId,
}) async {
  final focus = context.read<FocusController>();
  final isEditing = labelToEdit != null;
  final hasChildren = isEditing && focus.childrenOf(labelToEdit.id).isNotEmpty;
  final parents = focus.labels
      .where((p) => !p.isChild && (!isEditing || p.id != labelToEdit.id))
      .toList();

  final picked = await showDialog<_LabelDraft>(
    context: context,
    builder: (_) => _NewLabelDialog(
      title: isEditing
          ? context.l10n.focus_label_edit
          : context.l10n.focus_label_new,
      initialName: labelToEdit?.name,
      initialColor: labelToEdit?.color,
      initialParentId: labelToEdit?.parentId ?? preselectedParentId,
      parents: hasChildren ? const [] : parents,
    ),
  );
  if (picked == null || !context.mounted) return null;

  if (isEditing) {
    final ok = await focus.renameLabel(
      labelToEdit.id,
      picked.name,
      color: picked.color,
      parentId: picked.parentId,
      updateParent: true,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.focus_label_exists)),
      );
      return null;
    }
    return focus.labelById(labelToEdit.id);
  } else {
    return await focus.createLabel(
      name: picked.name,
      color: picked.color,
      parentId: picked.parentId,
    );
  }
}

class _NewLabelDialog extends StatefulWidget {
  const _NewLabelDialog({
    this.title,
    this.initialName,
    this.initialColor,
    this.initialParentId,
    this.parents = const [],
  });

  final String? title;
  final String? initialName;
  final Color? initialColor;
  final String? initialParentId;
  final List<FocusLabel> parents;

  @override
  State<_NewLabelDialog> createState() => _NewLabelDialogState();
}

class _NewLabelDialogState extends State<_NewLabelDialog> {
  late final TextEditingController _field;
  late final TextEditingController _hexField;
  late Color _color;
  String? _parentId;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: widget.initialName ?? '');
    _color = widget.initialColor ?? FocusController.defaultTagColors[0];
    _parentId = widget.initialParentId;
    _hexField = TextEditingController(
      text:
          '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );
  }

  @override
  void dispose() {
    _field.dispose();
    _hexField.dispose();
    super.dispose();
  }

  void _onHexChanged(String value) {
    final clean = value.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final parsed = int.tryParse('FF$clean', radix: 16);
      if (parsed != null) {
        setState(() => _color = Color(parsed));
      }
    }
  }

  void _selectColor(Color c) {
    setState(() {
      _color = c;
      _hexField.text =
          '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    });
  }

  void _done() {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(_LabelDraft(text, _color, _parentId));
  }

  @override
  Widget build(BuildContext context) {
    final canChooseParent = widget.parents.isNotEmpty;
    return AlertDialog(
      title: Text(widget.title ?? context.l10n.focus_label_new),
      content: SingleChildScrollView(
        child: Column(
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
            if (canChooseParent) ...[
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                value: _parentId,
                decoration: InputDecoration(
                  labelText: context.l10n.focus_label_parent,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(context.l10n.focus_label_no_parent),
                  ),
                  for (final parent in widget.parents)
                    DropdownMenuItem<String?>(
                      value: parent.id,
                      child: Text(parent.name),
                    ),
                ],
                onChanged: (value) => setState(() => _parentId = value),
              ),
            ],
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
                    onTap: () => _selectColor(color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _color == color
                            ? Border.all(
                                color: context.colors.onSurface,
                                width: 2.2,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _hexField,
                    maxLength: 7,
                    decoration: InputDecoration(
                      labelText: context.l10n.focus_label_hex,
                      hintText: '#10B981',
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _onHexChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
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
