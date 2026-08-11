// Prepares the launcher icon source from the raw logo.
//
// Run with: dart run tool/build_icon.dart
//
// The logo arrives as a mark floating in a large white field. Handed straight
// to flutter_launcher_icons that produces an icon whose artwork occupies about
// a third of the tile — legible on a design canvas, a smudge on a home screen
// next to Instagram. This crops to the ink and re-pads to a known ratio, so
// the mark is the icon rather than a detail inside it.
//
// Two outputs, because Android needs both:
//   icon.png            — the square legacy icon, mark on white
//   icon_foreground.png — the adaptive foreground, padded for the 66% safe
//                         zone that launchers mask into circles and squircles
import 'dart:io';

import 'package:image/image.dart';

void main() {
  final source = decodePng(File('assets/brand/logo_source.png').readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not read assets/brand/logo_source.png');
    exit(1);
  }

  final bounds = _inkBounds(source);
  stdout.writeln(
    'Ink occupies ${bounds.width}x${bounds.height} '
    'of ${source.width}x${source.height}',
  );

  final mark = copyCrop(
    source,
    x: bounds.left,
    y: bounds.top,
    width: bounds.width,
    height: bounds.height,
  );

  // Legacy icon: the mark filling 78% of the tile. Launchers apply their own
  // rounding to this one, so a little breathing room stops the ink touching a
  // rounded corner.
  _write('assets/brand/icon.png', _centre(mark, 1024, 0.78));

  // Adaptive foreground: 66% of the canvas is the guaranteed-visible safe
  // zone on every launcher shape. Anything outside it can be masked away, so
  // the mark sits inside it and the rest is transparent padding.
  _write(
    'assets/brand/icon_foreground.png',
    _centre(mark, 1024, 0.60, transparent: true),
  );

  stdout.writeln('Wrote assets/brand/icon.png and icon_foreground.png');
}

/// The tightest box containing anything that is not white.
_Bounds _inkBounds(Image image) {
  var left = image.width, top = image.height, right = 0, bottom = 0;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      // Anything meaningfully darker than paper, or anything with alpha in a
      // source that already has a transparent background.
      final dark = pixel.r < 240 || pixel.g < 240 || pixel.b < 240;
      if (pixel.a > 8 && dark) {
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }

  if (right <= left || bottom <= top) {
    return _Bounds(0, 0, image.width, image.height);
  }
  return _Bounds(left, top, right - left + 1, bottom - top + 1);
}

/// Scales [mark] to occupy [fill] of a [size] square and centres it.
Image _centre(Image mark, int size, double coverage, {bool transparent = false}) {
  final target = (size * coverage).round();
  final scale = target / (mark.width > mark.height ? mark.width : mark.height);

  final scaled = copyResize(
    mark,
    width: (mark.width * scale).round(),
    height: (mark.height * scale).round(),
    interpolation: Interpolation.cubic,
  );

  final canvas = Image(width: size, height: size, numChannels: 4);
  fill(
    canvas,
    color: transparent
        ? ColorRgba8(255, 255, 255, 0)
        : ColorRgba8(255, 255, 255, 255),
  );

  compositeImage(
    canvas,
    scaled,
    dstX: (size - scaled.width) ~/ 2,
    dstY: (size - scaled.height) ~/ 2,
  );

  return canvas;
}

void _write(String path, Image image) =>
    File(path).writeAsBytesSync(encodePng(image));

class _Bounds {
  const _Bounds(this.left, this.top, this.width, this.height);
  final int left, top, width, height;
}
