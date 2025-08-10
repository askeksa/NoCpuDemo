import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

class BlitterTornado {
  static final _depth = 2;
  static final _blockSize = 32;
  static final borderTop = 16;
  static final borderLeft = 64;
  static final _pattern = () {
    Random rng = Random(1337);
    return Bitmap.generate(
      80,
      80,
      (x, y) => rng.nextInt(16) == 0 ? 1 : 0,
      depth: 1,
    );
  }();

  final Bitmap bitmap1 = Bitmap.space(
    320 + borderLeft,
    180 + borderTop,
    _depth,
    interleaved: true,
  );
  final Bitmap bitmap2 = Bitmap.space(
    320 + borderLeft,
    180 + borderTop,
    _depth,
    interleaved: true,
  );

  Bitmap frontForFrame(int frame) => frame & 1 != 0 ? bitmap2 : bitmap1;
  Bitmap backForFrame(int frame) => frame & 1 != 0 ? bitmap1 : bitmap2;

  BlitterTornadoFrame frame(int frame, double angle, double zoom) {
    return BlitterTornadoFrame(this, frame, angle, zoom);
  }
}

class BlitterTornadoFrame implements CopperComponent {
  final BlitterTornado _blitterTornado;
  final int _frame;
  final double _angle;
  final double _zoom;

  late Bitmap back;
  late Bitmap front;

  BlitterTornadoFrame(
    this._blitterTornado,
    this._frame,
    this._angle,
    this._zoom,
  ) {
    back = _blitterTornado.backForFrame(_frame);
    front = _blitterTornado.frontForFrame(_frame);
  }

  List<Label> get frontPlanes => [
    for (int plane = 0; plane <= 1; ++plane)
      front.bitplanes +
          BlitterTornado.borderLeft ~/ 8 +
          BlitterTornado.borderTop * front.rowStride +
          plane * front.bytesPerRow,
  ];

  @override
  void addToCopper(Copper copper) {
    var offsetX = (_frame & 1) * 16;
    var offsetY = (_frame & 2) * 8;

    var centerX = -32;
    var centerY = -16;

    copper ^
        (copper) {
          var angle = _angle * (pi * 2 / 360);

          var dx = cos(angle) / _zoom;
          var dy = sin(angle) / _zoom;

          for (int y = 0; y < back.height; y += BlitterTornado._blockSize) {
            for (
              int x = back.width - BlitterTornado._blockSize;
              x >= 16;
              x -= BlitterTornado._blockSize
            ) {
              var centerDestX =
                  x +
                  BlitterTornado._blockSize ~/ 2 -
                  back.width ~/ 2 +
                  offsetX +
                  centerX;
              var centerDestY =
                  y +
                  BlitterTornado._blockSize ~/ 2 -
                  back.height ~/ 2 +
                  offsetY +
                  centerY;
              var centerSrcX = (centerDestX * dx + centerDestY * dy).round();
              var centerSrcY = (centerDestY * dx - centerDestX * dy).floor();

              var destX =
                  centerDestX -
                  centerX -
                  BlitterTornado._blockSize ~/ 2 +
                  back.width ~/ 2;
              var destY =
                  centerDestY -
                  centerY -
                  BlitterTornado._blockSize ~/ 2 +
                  back.height ~/ 2;
              var srcX =
                  centerSrcX -
                  centerX -
                  BlitterTornado._blockSize ~/ 2 +
                  back.width ~/ 2;
              var srcY =
                  centerSrcY -
                  centerY -
                  BlitterTornado._blockSize ~/ 2 +
                  back.height ~/ 2;

              var width = BlitterTornado._blockSize;
              var height = BlitterTornado._blockSize;

              if (destX < 0) {
                width += destX;
                destX = 0;
              }

              if (destY < 0) {
                height += destX;
                destX = 0;
              }

              if (destX + width > back.width) {
                width = back.width - destX;
                if (width < 0) {
                  continue;
                }
              }

              if (destY + height > back.height) {
                height = back.height - destY;
                if (height < 0) {
                  continue;
                }
              }

              if (srcY + height > front.height) {
                height = front.height - srcY;
              }

              var wordWidth = width ~/ 16;
              var destWord = destX ~/ 16 + destY * back.rowStride ~/ 2;
              var srcWord = srcX ~/ 16 + srcY * front.rowStride ~/ 2;
              var shift = srcX & 15;

              if (shift != 0) {
                shift = 16 - shift;
                destWord -= 1;
                wordWidth += 1;
              }

              // Shift the source to the right
              var blit = Blit()
                ..aPtr = front.bitplanes + srcWord * 2
                ..aStride = front.bytesPerRow
                ..aShift = shift
                ..dPtr = back.bitplanes + destWord * 2
                ..dStride = back.bytesPerRow
                ..width = wordWidth
                ..height = height * BlitterTornado._depth;
              copper << blit;
            }
          }
        };

    copper ^
        (copper) {
          if (_frame % 4 == 0) {
            for (int plane = 0; plane < BlitterTornado._depth; ++plane) {
              var patternWidth = 64;
              var patternHeight = 64;
              var f = (_frame + plane) % 9;
              var shiftX = (f >> 2 % 2) * 2;
              var shiftY = (f >> 3 % 16);
              var pattern = BlitterTornado._pattern;
              var destPtr =
                  back.bitplanes +
                  back.bytesPerRow * plane +
                  back.rowStride *
                      ((back.height - patternHeight) ~/ 2 + offsetY) +
                  ((back.width - patternWidth) ~/ 2 + offsetX - centerX) ~/
                      16 *
                      2;
              var shapeBlit = Blit()
                ..aPtr = pattern.bitplanes + shiftX + shiftY * pattern.rowStride
                ..aStride = pattern.rowStride
                ..cdPtr = destPtr
                ..cdStride = back.rowStride
                ..minterms = A ^ C
                ..width = patternWidth >> 4
                ..height = patternHeight;

              copper << shapeBlit;
            }
          }
        };
  }
}
