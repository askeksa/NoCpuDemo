import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

class Kaleidoscope {
  static final int depth = 1;
  static final int squareSize = 64;

  final Bitmap bitmap1 = Bitmap.space(320, 192, depth, interleaved: true);
  final Bitmap bitmap2 = Bitmap.space(320, 192, depth, interleaved: true);

  Bitmap frontForFrame(int frame) => frame & 1 != 0 ? bitmap2 : bitmap1;
  Bitmap backForFrame(int frame) => frame & 1 != 0 ? bitmap1 : bitmap2;

  KaleidoscopeFrame frame(int frame) {
    return KaleidoscopeFrame(this, frame);
  }

  KaleidoscopeFrameInit init(int frame) {
    return KaleidoscopeFrameInit(this, frame);
  }
}

class KaleidoscopeFrame implements CopperComponent {
  final Kaleidoscope _kaleidoscope;
  final int _frame;

  Bitmap get _back => _kaleidoscope.backForFrame(_frame);
  Bitmap get _front => _kaleidoscope.frontForFrame(_frame);

  KaleidoscopeFrame(this._kaleidoscope, this._frame);

  @override
  void addToCopper(Copper copper) {
    copper ^
        (copper) {
          // Draw one square
          void drawSquare(Bitmap bitmap, int x, List<(double, double)> coords) {
            for (int i = 0; i < coords.length; ++i) {
              copper <<
                  _drawLine(
                    bitmap.bitplanes + x ~/ 8,
                    coords[i],
                    coords[(i + 1) % coords.length],
                  );
            }

            copper <<
                (Blit()
                  ..aPtr = bitmap.bitplanes + x ~/ 8
                  ..dPtr = bitmap.bitplanes + x ~/ 8
                  ..aStride = bitmap.rowStride
                  ..dStride = bitmap.rowStride
                  ..exclusiveFill = true
                  ..width = Kaleidoscope.squareSize >> 4
                  ..height = Kaleidoscope.squareSize);
          }

          // Clear the first two squares
          copper <<
              (Blit()
                ..dPtr = _back.bitplanes
                ..dStride = _back.rowStride
                ..width = Kaleidoscope.squareSize * 2
                ..height = Kaleidoscope.squareSize);

          // Draw squares
          var center = Kaleidoscope.squareSize ~/ 2;

          (double, double) coord(double angle) => (
            (sin(angle) * (center + 20)) + center,
            (cos(angle) * (center + 20)) + center,
          );

          var angle = _frame / 90 * (2 * pi);
          var coords = List.generate(3, (i) => coord(angle + 2 * pi * i / 3));

          drawSquare(_back, 0, coords);
          drawSquare(
            _back,
            Kaleidoscope.squareSize,
            coords
                .map<(double, double)>(
                  (coord) => (Kaleidoscope.squareSize - coord.$1, coord.$2),
                )
                .toList(),
          );

          // Fill back buffer with squares
          copper ^
              (copper) {
                // Copy column 1 and 2 to 3, 4, and 5
                copper <<
                    (Blit()
                      ..aPtr = _back.bitplanes
                      ..aStride = _back.rowStride
                      ..dPtr =
                          _back.bitplanes + (Kaleidoscope.squareSize * 2) ~/ 8
                      ..dStride = _back.planeStride
                      ..width = (Kaleidoscope.squareSize * 3) >> 4
                      ..height = (Kaleidoscope.squareSize));

                // Copy mirrored row to second row
                copper <<
                    (Blit()
                      ..aPtr = _back.bitplanes
                      ..aStride = _back.rowStride
                      ..dPtr =
                          _back.bitplanes +
                          ((Kaleidoscope.squareSize * 2 - 1) * _back.rowStride)
                      ..dStride = -_back.planeStride
                      ..width = (Kaleidoscope.squareSize * 5) >> 4
                      ..height = (Kaleidoscope.squareSize));

                // Copy row to third row
                copper <<
                    (Blit()
                      ..aPtr = _back.bitplanes
                      ..aStride = _back.rowStride
                      ..dPtr =
                          _back.bitplanes +
                          ((Kaleidoscope.squareSize * 2) * _back.rowStride)
                      ..dStride = _back.planeStride
                      ..width = (Kaleidoscope.squareSize * 5) >> 4
                      ..height = (Kaleidoscope.squareSize));
              };
        };
  }

  BlitList _drawLine(
    Label bitplane,
    (double, double) start,
    (double, double) end,
  ) {
    var blits = BlitList([]);

    // If outside right hand side, make it a vertical line
    if (start.$1 >= Kaleidoscope.squareSize &&
        end.$1 >= Kaleidoscope.squareSize) {
      start = (Kaleidoscope.squareSize - 1, start.$2);
      end = (Kaleidoscope.squareSize - 1, end.$2);
    }
    // Check if completely outside area (not the right hand side, as that requires a vertical line to be drawn in order to fill correctly)
    if ((start.$2 < 0 && end.$2 < 0) ||
        (start.$1 < 0 && end.$1 < 0) ||
        (start.$2 >= Kaleidoscope.squareSize &&
            end.$2 >= Kaleidoscope.squareSize)) {
      return blits;
    }
    // Turn top to bottom
    if (start.$2 > end.$2) {
      (start, end) = (end, start);
    }
    double getXAtY(double atY) =>
        (end.$1 - start.$1) * (atY - start.$2) / (end.$2 - start.$2) + start.$1;
    if (start.$2 < 0) {
      start = (getXAtY(0), 0);
    }
    if (end.$2 >= Kaleidoscope.squareSize) {
      end = (
        getXAtY(Kaleidoscope.squareSize.toDouble()),
        Kaleidoscope.squareSize.toDouble(),
      );
    }
    // Turn left to right
    if (start.$1 > end.$1) {
      (start, end) = (end, start);
    }
    double getYAtX(double atX) =>
        (end.$2 - start.$2) * (atX - start.$1) / (end.$1 - start.$1) + start.$2;

    if (start.$1 < 0) {
      start = (0, getYAtX(0));
    }
    if (end.$1 >= Kaleidoscope.squareSize) {
      var newEndY = getYAtX(Kaleidoscope.squareSize.toDouble());
      blits = _drawLine(
        bitplane,
        (Kaleidoscope.squareSize.toDouble(), end.$2),
        (Kaleidoscope.squareSize.toDouble(), newEndY),
      );
      end = (Kaleidoscope.squareSize.toDouble(), newEndY);
    }

    return blits +
        [
          Blit()
            ..dPtr = bitplane
            ..dStride = _back.rowStride
            ..lineStart = (
              start.$1.toInt().clamp(0, Kaleidoscope.squareSize - 1),
              start.$2.toInt(),
            )
            ..lineEnd = (
              end.$1.toInt().clamp(0, Kaleidoscope.squareSize - 1),
              end.$2.toInt(),
            ),
        ];
  }
}

class KaleidoscopeFrameInit implements CopperComponent {
  final Kaleidoscope _kaleidoscope;
  final int _frame;

  KaleidoscopeFrameInit(this._kaleidoscope, this._frame);

  @override
  void addToCopper(Copper copper) {
    copper ^
        (copper) {
          var bitmap = _frame == 0
              ? _kaleidoscope.bitmap1
              : _kaleidoscope.bitmap2;
          copper <<
              (Blit()
                ..dPtr = bitmap.bitplanes
                ..dStride = bitmap.planeStride
                ..width = bitmap.width >> 4
                ..height = bitmap.height);
        };
  }
}
