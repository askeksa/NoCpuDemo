import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

class KaleidoscopeSpriteSet {
  late final Sprite column1 = Sprite.space(3 * Kaleidoscope.squareSize);
  late final Sprite column2 = Sprite.space(3 * Kaleidoscope.squareSize);
  late final Sprite column3 = Sprite.space(1);
  late final Sprite column4 = Sprite.space(1);
  late final Sprite column5 = Sprite.space(1);

  late final columns = [column1, column2, column3, column4, column5];
}

class Kaleidoscope {
  static final int depth = 2;
  static final int squareSize = 64;

  final sprites1 = KaleidoscopeSpriteSet();
  final sprites2 = KaleidoscopeSpriteSet();

  Display displayForFrame(int frame) {
    var front = frontForFrame(frame);
    return Display()..sprites = front.columns.map((e) => e.label).toList();
  }

  KaleidoscopeSpriteSet frontForFrame(int frame) =>
      frame & 1 != 0 ? sprites2 : sprites1;
  KaleidoscopeSpriteSet backForFrame(int frame) =>
      frame & 1 != 0 ? sprites1 : sprites2;

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

  KaleidoscopeSpriteSet get _back => _kaleidoscope.backForFrame(_frame);

  KaleidoscopeFrame(this._kaleidoscope, this._frame);

  (double, double) rotate((double, double) coord, double angle) => (
    coord.$1 * cos(angle) - coord.$2 * sin(angle),
    coord.$1 * sin(angle) + coord.$2 * cos(angle),
  );

  (double, double) center((double, double) coord) => (
    coord.$1 + Kaleidoscope.squareSize ~/ 2,
    coord.$2 + Kaleidoscope.squareSize ~/ 2,
  );

  List<(double, double)> triangleCoords() {
    var angle = -_frame / 128 * (2 * pi);
    var center = Kaleidoscope.squareSize / 2;

    (double, double) coord(double angle) => (
      (sin(angle) * (center + 20)) + center,
      (cos(angle) * (center + 20)) + center,
    );

    return List.generate(3, (i) => coord(angle + 2 * pi * i / 3));
  }

  List<(double, double)> barCoords() {
    var angle = -_frame / 128 * (2 * pi);

    var coords = [(-10.0, -50.0), (10.0, -50.0), (10.0, 50.0), (-10.0, 50.0)];

    return coords
        .map((e) => rotate((e.$1 - 20, e.$2), angle))
        .map(center)
        .toList();
  }

  @override
  void addToCopper(Copper copper) {
    copper ^
        (copper) {
          // Clear the first two squares
          for (int i = 0; i <= 1; ++i) {
            copper <<
                (Blit()..dSetInterleaved(
                  _back.columns[i].bitmap,
                  h: Kaleidoscope.squareSize,
                ));
          }

          // Calculate pattern
          List<(double, double)> mirrorShape(List<(double, double)> shape) =>
              shape
                  .map<(double, double)>(
                    (coord) => (Kaleidoscope.squareSize - coord.$1, coord.$2),
                  )
                  .toList();

          var shapes = [triangleCoords(), barCoords()];
          var mirroredShapes = shapes.map(mirrorShape).toList();

          // Draw shapes
          for (int s = 0; s <= 1; ++s) {
            drawSquare(
              copper,
              _back.column1.bitmap.bitplanes + s * 8,
              _back.column1.bitmap.rowStride,
              shapes[s],
            );
            drawSquare(
              copper,
              _back.column2.bitmap.bitplanes + s * 8,
              _back.column2.bitmap.rowStride,
              mirroredShapes[s],
            );
            /*
            drawSquare(
              copper,
              _back.column1.bitmap.bitplanes + 8,
              _back.column1.bitmap.rowStride,
              mirroredShapes[s],
            );
            */
          }

          // Fill back buffer with squares
          copper ^
              (copper) {
                for (int i = 0; i <= 1; ++i) {
                  fillSprite(i, copper);
                }
                copper.wait(v: 26);
                copper.ptr(SPR2PT, _back.column1.bitmap.bitplanes);
                copper.ptr(SPR3PT, _back.column2.bitmap.bitplanes);
                copper.ptr(SPR4PT, _back.column1.bitmap.bitplanes);
              };
        };
  }

  void fillSprite(int i, Copper copper) {
    var bitmap = _back.columns[i].bitmap;

    // Mirror first sprite square to next one down
    copper <<
        (Blit()
          ..aPtr = bitmap.bitplanes
          ..aStride = bitmap.rowStride
          ..dPtr =
              bitmap.bitplanes +
              (Kaleidoscope.squareSize * 2 - 1) * bitmap.rowStride
          ..dStride = -bitmap.rowStride
          ..width = (bitmap.width * 2) >> 4
          ..height = Kaleidoscope.squareSize);

    // First sprite square to third row
    copper <<
        (Blit()
          ..aPtr = bitmap.bitplanes
          ..aStride = bitmap.bytesPerRow
          ..dPtr =
              bitmap.bitplanes + Kaleidoscope.squareSize * 2 * bitmap.rowStride
          ..dStride = bitmap.bytesPerRow
          ..width = bitmap.width >> 4
          ..height = Kaleidoscope.squareSize * 2);
  }

  BlitList<LineBlit> _drawLine(
    Label bitplane,
    int rowStride,
    (double, double) start,
    (double, double) end,
  ) {
    var blits = BlitList<LineBlit>([]);

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
        rowStride,
        (Kaleidoscope.squareSize.toDouble(), end.$2),
        (Kaleidoscope.squareSize.toDouble(), newEndY),
      );
      end = (Kaleidoscope.squareSize.toDouble(), newEndY);
    }

    return blits +
        [
          LineBlit()
            ..dPtr = bitplane
            ..dStride = rowStride
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

  // Draw one square
  void drawSquare(
    Copper copper,
    Label bitplanes,
    int rowStride,
    List<(double, double)> coords,
  ) {
    for (int i = 0; i < coords.length; ++i) {
      copper <<
          _drawLine(
            bitplanes,
            rowStride,
            coords[i],
            coords[(i + 1) % coords.length],
          );
    }

    copper <<
        (Blit()
          ..aPtr = bitplanes
          ..dPtr = bitplanes
          ..aStride = rowStride
          ..dStride = rowStride
          ..exclusiveFill = true
          ..width = Kaleidoscope.squareSize >> 4
          ..height = Kaleidoscope.squareSize);
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
          void updateControlWords(Sprite sprite, int h, int height) {
            copper <<
                (sprite.updatePosition(
                  h: 0x200 + h * 4,
                  v: 82,
                  height: height,
                ));
            copper << (sprite.updateTerminator());
          }

          void clearBitmapSprite(int h, Sprite sprite) {
            copper <<
                (Blit()
                  ..dSetInterleaved(sprite.bitmap)
                  ..aData = 0xFFFF);
            updateControlWords(sprite, h, Kaleidoscope.squareSize * 3);
          }

          var back = _kaleidoscope.backForFrame(_frame);
          for (int i = 0; i <= 1; ++i) {
            clearBitmapSprite(Kaleidoscope.squareSize * i, back.columns[i]);
          }
          for (int i = 2; i <= 4; ++i) {
            updateControlWords(
              back.columns[i],
              Kaleidoscope.squareSize * i,
              Kaleidoscope.squareSize * 3,
            );
          }
        };
  }
}
