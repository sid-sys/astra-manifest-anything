import 'package:flutter/material.dart';

/// The orb.
///
/// A rendered animation now, not a painting. It was a [CustomPainter] — three
/// layers of gradient and blur turning under a fixed highlight — because there
/// was nothing else to show, and it did the job: something alive on screen for
/// the ninety seconds a manifestation takes to write.
///
/// It could not do this. The bubble is an iridescent film with light bending
/// through it and swirling underneath, and no arrangement of circles and blurs
/// gets there. So the drawing is gone and the artwork is in.
///
/// Two files, because the paused state has to be still. An animated WebP has
/// no seek and no pause in Flutter — [Image] plays it, start to finish, over
/// and over — so parking it means showing a frame instead, and `orb_still.png`
/// is frame 20 of the same clip put through the same cutout. They are the same
/// picture; only one of them moves.
///
/// The loop is a real loop. The clip's first and last frames do not match, so
/// the file plays forward and then backward — six seconds out of three — and
/// the join is invisible on motion this slow.
class AstraOrb extends StatelessWidget {
  const AstraOrb({super.key, this.size = 180, this.spinning = true});

  final double size;

  /// False shows the still. Used where the orb is decoration on a screen that
  /// is not doing anything — the player when it is paused — because motion
  /// that never stops stops meaning anything.
  final bool spinning;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Image.asset(
      spinning ? 'assets/brand/orb.webp' : 'assets/brand/orb_still.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Holds the last frame while the other file decodes, so pausing does not
      // blink a hole in the screen.
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      // The orb is decoration everywhere it appears — the screens it sits on
      // say what is happening in words directly underneath it.
      excludeFromSemantics: true,
    ),
  );
}
