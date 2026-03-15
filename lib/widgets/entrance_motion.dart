import 'package:flutter/material.dart';

class EntranceMotion extends StatefulWidget {
  const EntranceMotion({
    super.key,
    required this.child,
    this.active = true,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeInOutCubic,
    this.beginOffset = const Offset(-0.08, 0),
  });

  final Widget child;
  final bool active;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Offset beginOffset;

  @override
  State<EntranceMotion> createState() => _EntranceMotionState();
}

class _EntranceMotionState extends State<EntranceMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _configureAnimations();
    if (widget.active) {
      _startAnimation();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant EntranceMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.curve != widget.curve ||
        oldWidget.beginOffset != widget.beginOffset) {
      _controller.duration = widget.duration;
      _configureAnimations();
    }

    if (widget.active && !oldWidget.active) {
      _startAnimation();
    } else if (!widget.active && oldWidget.active) {
      _controller.value = 1;
    }
  }

  void _configureAnimations() {
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(curved);
  }

  Future<void> _startAnimation() async {
    final runId = ++_runId;
    _controller.value = 0;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (!mounted || runId != _runId) {
      return;
    }
    await _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
