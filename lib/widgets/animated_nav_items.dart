import 'package:flutter/material.dart';

class AnimatedNavTile extends StatefulWidget {
  const AnimatedNavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.margin,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;

  @override
  State<AnimatedNavTile> createState() => _AnimatedNavTileState();
}

class _AnimatedNavTileState extends State<AnimatedNavTile> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final highlightColor = widget.selected
        ? scheme.primary.withValues(alpha: 0.16)
        : _pressed
        ? scheme.primary.withValues(alpha: 0.12)
        : _hovered
        ? scheme.primary.withValues(alpha: 0.08)
        : Colors.transparent;
    final borderColor = widget.selected
        ? scheme.primary.withValues(alpha: 0.24)
        : _hovered
        ? scheme.outlineVariant.withValues(alpha: 0.75)
        : Colors.transparent;
    final foregroundColor = widget.selected
        ? scheme.primary
        : _hovered
        ? scheme.onSurface
        : scheme.onSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        if (mounted) {
          setState(() {
            _hovered = false;
            _pressed = false;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        margin:
            widget.margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: highlightColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (mounted) {
                setState(() => _pressed = value);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: widget.selected || _hovered
                          ? scheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: foregroundColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      style:
                          (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
                            color: foregroundColor,
                            fontWeight: widget.selected || _hovered
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                      child: Text(widget.label),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedNavPillButton extends StatefulWidget {
  const AnimatedNavPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<AnimatedNavPillButton> createState() => _AnimatedNavPillButtonState();
}

class _AnimatedNavPillButtonState extends State<AnimatedNavPillButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backgroundColor = widget.selected
        ? scheme.primary.withValues(alpha: 0.16)
        : _pressed
        ? scheme.primary.withValues(alpha: 0.12)
        : _hovered
        ? scheme.primary.withValues(alpha: 0.08)
        : Colors.transparent;
    final foregroundColor = widget.selected
        ? scheme.primary
        : _hovered
        ? scheme.onSurface
        : scheme.onSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        if (mounted) {
          setState(() {
            _hovered = false;
            _pressed = false;
          });
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          onHighlightChanged: (value) {
            if (mounted) {
              setState(() => _pressed = value);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.selected
                    ? scheme.primary.withValues(alpha: 0.22)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: foregroundColor),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOutCubic,
                  style: (theme.textTheme.labelMedium ?? const TextStyle())
                      .copyWith(
                        color: foregroundColor,
                        fontWeight: widget.selected || _hovered
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
