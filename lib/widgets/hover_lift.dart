import 'package:flutter/material.dart';

class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 220),
    this.hoverOffset = 8,
    this.hoverScale = 1.0,
    this.normalElevation = 0,
    this.hoverElevation = 0,
    this.borderRadius,
  });

  final Widget child;
  final bool enabled;
  final Duration duration;
  final double hoverOffset;
  final double hoverScale;
  final double normalElevation;
  final double hoverElevation;
  final BorderRadius? borderRadius;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: widget.duration,
        curve: Curves.easeInOutCubic,
        transform: Matrix4.identity()
          ..translateByDouble(0, _hovered ? -widget.hoverOffset : 0, 0, 1)
          ..scaleByDouble(
            _hovered ? widget.hoverScale : 1.0,
            _hovered ? widget.hoverScale : 1.0,
            1.0,
            1.0,
          ),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: [
            if (widget.hoverElevation > 0 || widget.normalElevation > 0)
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: _hovered ? 0.14 : 0.06,
                ),
                blurRadius: _hovered
                    ? widget.hoverElevation
                    : widget.normalElevation,
                offset: Offset(0, _hovered ? 14 : 6),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
