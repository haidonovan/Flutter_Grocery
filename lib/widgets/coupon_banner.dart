import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../client/models.dart';

class CouponBanner extends StatelessWidget {
  const CouponBanner({super.key, required this.coupon});

  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    final valueLabel = coupon.type == 'percent'
        ? '${coupon.value.toStringAsFixed(0)}%'
        : '\$${coupon.value.toStringAsFixed(0)}';
    final endLabel = coupon.endsAt == null
        ? 'No expiry'
        : coupon.endsAt!.toLocal().toString().split(' ').first;

    final dustyRose = const Color(0xFFC88B8B);
    final onDusty = const Color(0xFF3B1D1D);
    final mainBg = dustyRose.withValues(alpha: 0.95);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(320.0, 720.0).toDouble();
        final height = width < 420 ? 200.0 : 240.0;
        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Container(color: mainBg),
                Positioned(
                  right: -40,
                  top: -20,
                  child: Icon(
                    Icons.local_grocery_store_outlined,
                    size: 180,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                Positioned(
                  left: 140,
                  bottom: -20,
                  child: Icon(
                    Icons.bakery_dining_outlined,
                    size: 160,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                Positioned(
                  right: 60,
                  bottom: 10,
                  child: Icon(
                    Icons.local_drink_outlined,
                    size: 140,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                Positioned(
                  left: -12,
                  top: height * 0.35,
                  child: _Cutout(color: Theme.of(context).colorScheme.surface),
                ),
                Positioned(
                  left: -12,
                  bottom: height * 0.35,
                  child: _Cutout(color: Theme.of(context).colorScheme.surface),
                ),
                Positioned(
                  right: -12,
                  top: height * 0.35,
                  child: _Cutout(color: Theme.of(context).colorScheme.surface),
                ),
                Positioned(
                  right: -12,
                  bottom: height * 0.35,
                  child: _Cutout(color: Theme.of(context).colorScheme.surface),
                ),
                CustomPaint(
                  size: Size(width, height),
                  painter: _PerforationPainter(),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: width * 0.24,
                      height: height,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              'DISCOUNT',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                color: onDusty,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            valueLabel,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: onDusty,
                            ),
                          ),
                          const SizedBox(height: 10),
                          RotatedBox(
                            quarterTurns: 3,
                            child: _Barcode(color: onDusty),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 16, 20, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.shopping_basket_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Fresh Market Grocery',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'GROCERY',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'COUPON',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                height: 0.9,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              coupon.description ?? 'Fresh Market Savings',
                              style: GoogleFonts.dancingScript(
                                fontSize: 22,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Valid Until: $endLabel',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ),
                                Text(
                                  coupon.code,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final x = size.width * 0.2;
    const dashHeight = 8;
    const dashSpace = 8;
    var y = 16.0;
    while (y < size.height - 20) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dashHeight), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Cutout extends StatelessWidget {
  const _Cutout({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Barcode extends StatelessWidget {
  const _Barcode({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          10,
          (index) => Container(
            width: index.isEven ? 2 : 3,
            color: color.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
