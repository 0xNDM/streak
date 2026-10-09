import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as cp;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_palette.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';

class ColorPicker extends StatefulWidget {
  const ColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late bool _custom = _isCustom(widget.selected);
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(
      text: _toHex(widget.selected),
    );
  }

  @override
  void didUpdateWidget(ColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      final hex = _toHex(widget.selected);
      if (_hexController.text.toUpperCase() != hex) {
        _hexController.text = hex;
      }
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _toHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _onHexChanged(String text) {
    var raw = text.trim();
    if (raw.startsWith('#')) raw = raw.substring(1);
    if (raw.length == 6) {
      final val = int.tryParse('FF$raw', radix: 16);
      if (val != null) {
        widget.onSelected(Color(val));
      }
    }
  }

  bool _isCustom(Color color) => !AppPalette.habitColors
      .any((c) => c.toARGB32() == color.toARGB32());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Segment2(
          left: context.l10n.colors_tab,
          right: context.l10n.custom,
          rightActive: _custom,
          onChanged: (v) => setState(() => _custom = v),
        ),
        const SizedBox(height: 14),
        if (_custom)
          Column(
            children: [
              Center(
                child: cp.HueRingPicker(
                  pickerColor: widget.selected,
                  onColorChanged: (c) {
                    widget.onSelected(c);
                    _hexController.text = _toHex(c);
                  },
                  enableAlpha: false,
                  displayThumbColor: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.selected,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _hexController,
                      maxLength: 7,
                      decoration: const InputDecoration(
                        labelText: 'Hex Color',
                        hintText: '#10B981',
                        counterText: '',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: _onHexChanged,
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const columns = 8;
              const spacing = 10.0;
              final swatch =
                  ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                      .clamp(30.0, 40.0);
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final color in AppPalette.habitColors)
                    _Swatch(
                      color: color,
                      size: swatch,
                      selected:
                          widget.selected.toARGB32() == color.toARGB32(),
                      onTap: () => widget.onSelected(color),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Segment2 extends StatelessWidget {
  const _Segment2({
    required this.left,
    required this.right,
    required this.rightActive,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool rightActive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    Widget seg(String label, bool active, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: active,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? scheme.onPrimary : context.tokens.muted,
                  ),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          seg(left, !rightActive, () => onChanged(false)),
          seg(right, rightActive, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checkColor =
        color.computeLuminance() > 0.6 ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor =
        color.computeLuminance() > 0.85 ? const Color(0xFF8E8E93) : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.a11y_pick_color,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: borderColor, width: 2.5) : null,
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)]
                : null,
          ),
          child: selected
              ? Icon(LucideIcons.check, color: checkColor, size: 18)
              : null,
        ),
      ),
    );
  }
}
