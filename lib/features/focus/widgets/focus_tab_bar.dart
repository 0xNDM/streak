import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streak/app/theme/app_tokens.dart';

/// Page-level intent for moving between tabs (e.g. Ctrl+Tab).
class FocusTabMoveIntent extends Intent {
  const FocusTabMoveIntent(this.offset);

  final int offset;
}

/// Wraps a subtree so Ctrl+Tab / Ctrl+Shift+Tab cycle [tabCount] tabs.
class FocusTabShortcuts extends StatelessWidget {
  const FocusTabShortcuts({
    super.key,
    required this.tabCount,
    required this.index,
    required this.onSelect,
    required this.child,
  });

  final int tabCount;
  final int index;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab):
            const FocusTabMoveIntent(1),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.tab,
        ): const FocusTabMoveIntent(-1),
      },
      child: Actions(
        actions: {
          FocusTabMoveIntent: CallbackAction<FocusTabMoveIntent>(
            onInvoke: (intent) {
              final next =
                  (index + intent.offset + tabCount) % tabCount.clamp(1, 1 << 30);
              onSelect(next);
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

/// Underline tab bar: intrinsic-width tabs with a rounded indicator that
/// slides between tabs, hover wash, and full-height hit targets.
class UnderlineTabs extends StatefulWidget {
  const UnderlineTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  State<UnderlineTabs> createState() => _UnderlineTabsState();
}

class _UnderlineTabsState extends State<UnderlineTabs> {
  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> _tabKeys = [];
  final List<Rect> _rects = [];

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant UnderlineTabs old) {
    super.didUpdateWidget(old);
    if (old.tabs.length != widget.tabs.length) {
      _tabKeys.clear();
      _rects.clear();
      _syncKeys();
    }
  }

  void _syncKeys() {
    while (_tabKeys.length < widget.tabs.length) {
      _tabKeys.add(GlobalKey());
    }
  }

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stackBox =
          _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (stackBox == null || !stackBox.attached) return;
      var changed = false;
      for (var i = 0; i < _tabKeys.length; i++) {
        final box =
            _tabKeys[i].currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) continue;
        final rect = box.localToGlobal(Offset.zero, ancestor: stackBox) &
            box.size;
        if (i >= _rects.length) {
          _rects.add(rect);
          changed = true;
        } else if (_rects[i] != rect) {
          _rects[i] = rect;
          changed = true;
        }
      }
      if (changed && mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    _measure();

    final active =
        widget.index >= 0 && widget.index < _rects.length ? _rects[widget.index] : null;

    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: active?.left ?? 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: active?.width ?? 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.tabs.length; i++)
              _TabButton(
                key: _tabKeys[i],
                label: widget.tabs[i],
                selected: i == widget.index,
                onTap: () => widget.onChanged(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        hoverColor: scheme.primary.withValues(alpha: 0.08),
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? scheme.onSurface : context.tokens.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
