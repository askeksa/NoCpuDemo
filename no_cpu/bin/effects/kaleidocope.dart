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

  final Bitmap _square1 = Bitmap.space(
    Kaleidoscope.squareSize,
    Kaleidoscope.squareSize,
    1,
  );

  final Bitmap _square2 = Bitmap.space(
    Kaleidoscope.squareSize,
    Kaleidoscope.squareSize,
    1,
  );

  Bitmap get _back => _kaleidoscope.backForFrame(_frame);
  Bitmap get _front => _kaleidoscope.frontForFrame(_frame);

  KaleidoscopeFrame(this._kaleidoscope, this._frame);

  @override
  void addToCopper(Copper copper) {
    copper ^
        (copper) {
          // Draw one square
          void drawSquare(Bitmap bitmap, List<(int, int)> coords) {
            copper << (Blit()..dSetBitplane(bitmap, 0));

            for (int i = 0; i < coords.length; ++i) {
              copper <<
                  (Blit()
                    ..dPtr = bitmap.bitplanes
                    ..dStride = bitmap.rowStride
                    ..lineStart = coords[i]
                    ..lineEnd = coords[(i + 1) % coords.length]);
            }

            copper <<
                (Blit()
                  ..aPtr = bitmap.bitplanes
                  ..dPtr = bitmap.bitplanes
                  ..aStride = bitmap.rowStride
                  ..dStride = bitmap.rowStride
                  ..exclusiveFill = true
                  ..width = bitmap.width >> 4
                  ..height = bitmap.height);
          }

          //
          var center = Kaleidoscope.squareSize ~/ 2;

          (int, int) coord(double angle) => (
            (sin(angle) * (center - 1)).toInt() + center,
            (cos(angle) * (center - 1)).toInt() + center,
          );

          var angle = _frame / 100 * (2 * pi);
          var coords = List.generate(3, (i) => coord(angle + 2 * pi * i / 3));

          drawSquare(_square1, coords);
          drawSquare(
            _square2,
            coords
                .map<(int, int)>(
                  (coord) => (Kaleidoscope.squareSize - coord.$1, coord.$2),
                )
                .toList(),
          );

          // Copy to back buffer
          copper |
              (copper) {
                // Copy square1 to first column
                copper <<
                    (Blit()
                      ..aPtr = _square1.bitplanes
                      ..aStride = _square1.rowStride
                      ..dPtr = _back.bitplanes
                      ..dStride = _back.planeStride
                      ..width = _square1.width >> 4
                      ..height = _square1.height);

                // Copy square2 to second column
                copper <<
                    (Blit()
                      ..aPtr = _square2.bitplanes
                      ..aStride = _square2.rowStride
                      ..dPtr = _back.bitplanes + Kaleidoscope.squareSize ~/ 8
                      ..dStride = _back.planeStride
                      ..width = _square2.width >> 4
                      ..height = _square2.height);

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
