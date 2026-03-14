import 'package:flutter/material.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final double height;
  final double width;
  final BorderRadius borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1C2430)
        : const Color(0xFFE9ECEF);
    final highlightColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A3545)
        : const Color(0xFFF6F7F9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1 - _controller.value, -0.3),
              end: Alignment(1 + _controller.value, 0.3),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: widget.borderRadius,
            ),
          ),
        );
      },
    );
  }
}
