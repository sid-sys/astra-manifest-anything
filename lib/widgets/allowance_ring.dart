import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';

/// How much of the plan is left, as a ring.
///
/// A ring rather than a bar because this is a small number against a small
/// number — 1 of 2, 3 of 20 — and a bar at that scale is a stub that reads as
/// broken. A ring at 5% still looks like a ring.
///
/// The arc is drawn as *remaining* rather than consumed. What the user wants to
/// know standing in front of the box is how many they still have.
class AllowanceRing extends StatelessWidget {
  const AllowanceRing({
    super.key,
    required this.usage,
    this.size = 74,
    this.onTap,
  });

  final Usage usage;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final limit = usage.limit;
    final left = usage.left;

    // No limit means the free day is finished and there is no allowance to
    // draw. An empty ring would imply zero of something; a full grey one would
    // imply everything is fine.
    final fraction = limit == null ? 0.0 : left / limit;

    final ring = Semantics(
      label: limit == null
          ? '${usage.plan} plan, manifestations need Maya Plus'
          : '${usage.plan} plan, $left of $limit manifestations left',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: fraction,
            empty: limit == null || left == 0,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  limit == null ? '0' : '$left',
                  style: AstraTextStyles.display(
                    size * 0.32,
                    color: left == 0 ? AstraColors.dim : AstraColors.text,
                  ),
                ),
                Text(
                  limit == null ? 'left' : 'of $limit',
                  style: AstraTextStyles.small.copyWith(fontSize: size * 0.13),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return ring;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: ring,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.empty});

  final double fraction;
  final bool empty;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AstraColors.accent.withValues(alpha: 0.12);

    canvas.drawCircle(centre, radius, track);

    if (empty || fraction <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      // The gradient is the same one the primary button uses, so the ring
      // reads as belonging to the thing it is metering.
      ..shader = AstraColors.accentGradient.createShader(rect);

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      // Twelve o'clock, clockwise.
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.empty != empty;
}

/// The ring, the plan it belongs to, and what the other plans allow.
///
/// The comparison is the point: a number on its own ("2 left") says nothing
/// about whether that is generous, but "2 left · Plus writes 10 a month" tells
/// someone both where they stand and what the upgrade buys.
class AllowanceCard extends StatelessWidget {
  const AllowanceCard({super.key, required this.usage, this.onTap});

  final Usage usage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        AllowanceRing(usage: usage),
        const SizedBox(width: AstraSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(usage.plan, style: AstraTextStyles.label),
              const SizedBox(height: 2),
              Text(usage.detail, style: AstraTextStyles.small),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AstraColors.dim,
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AstraColors.card,
        borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
        boxShadow: AstraColors.softShadow,
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
              child: content,
            ),
    );
  }
}
