import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

class PartialLineBlit implements CopperComponent {
  final Label bitplane;
  final int startWord; // BLTCPT, BLTDPT
  final int bltaptl;
  final int bltcon0;
  final int bltcon1;
  final int bltbmod;
  final int bltamod;
  final int bltsize;

  PartialLineBlit(
    this.bitplane,
    this.startWord,
    this.bltaptl,
    this.bltcon0,
    this.bltcon1,
    this.bltbmod,
    this.bltamod,
    this.bltsize,
  );

  @override
  void addToCopper(Copper copper) {
    copper.waitBlit();
    copper.low(BLTCPTL, bitplane + startWord);
    copper.low(BLTDPTL, bitplane + startWord);
    copper.move(BLTAPTL, bltaptl);
    copper.move(BLTCON0, bltcon0);
    copper.move(BLTCON1, bltcon1);
    copper.move(BLTBMOD, bltbmod);
    copper.move(BLTAMOD, bltamod);
    copper.move(BLTSIZE, bltsize);
  }
}

class KaleidoscopeSpriteSet {
  late final Sprite column1 = Sprite.space(6 * Kaleidoscope.squareSize);
  late final Sprite column2 = Sprite.space(1);
  late final Sprite column3 = Sprite.space(1);
  late final Sprite column4 = Sprite.space(1);
  late final Sprite column5 = Sprite.space(1);

  late final columns = [column1, column2, column3, column4, column5];
}

class Kaleidoscope {
  static final int depth = 2;
  static final int squareSize = 32;

  final sprites = KaleidoscopeSpriteSet();

  final int cycleLength;
  final int frameSkip;

  Kaleidoscope(this.cycleLength, this.frameSkip);

  Display displayForFrame(int frame) {
    var front = frontForFrame(frame);
    return Display()..sprites = front.columns.map((e) => e.label).toList();
  }

  KaleidoscopeSpriteSet frontForFrame(int frame) => sprites;
  KaleidoscopeSpriteSet backForFrame(int frame) => sprites;

  KaleidoscopeFrame frame(int frame) {
    return KaleidoscopeFrame(this, frame - frame % frameSkip);
  }

  KaleidoscopeFrameFooter footer(int frame) {
    return KaleidoscopeFrameFooter(this, frame - frame % frameSkip);
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
    var angle = -_frame / _kaleidoscope.cycleLength * (2 * pi);
    var center = Kaleidoscope.squareSize / 2;

    (double, double) coord(double angle) => (
      (sin(angle) * (center * 1.5)) + center,
      (cos(angle) * (center * 1.5)) + center,
    );

    return List.generate(3, (i) => coord(angle + 2 * pi * i / 3));
  }

  List<(double, double)> barCoords() {
    var angle = -_frame / _kaleidoscope.cycleLength * (2 * pi);

    var coords = [(-10.0, -50.0), (10.0, -50.0), (10.0, 50.0), (-10.0, 50.0)];

    return coords
        .map((e) => rotate(((e.$1 - 10) * 0.5, e.$2 * 0.5), angle))
        .map(center)
        .toList();
  }

  @override
  void addToCopper(Copper copper) {
    copper ^
        (copper) {
          // Clear the first two squares
          copper <<
              (Blit()..dSetInterleaved(
                _back.column1.bitmap,
                h: Kaleidoscope.squareSize,
              ));

          // Calculate pattern
          List<(double, double)> mirrorShape(List<(double, double)> shape) =>
              shape
                  .map<(double, double)>(
                    (coord) => (Kaleidoscope.squareSize - coord.$1, coord.$2),
                  )
                  .toList();

          var shapes = [triangleCoords(), barCoords()];
          var mirroredShapes = shapes.map(mirrorShape).toList();

          // Prepare line draw
          copper.waitBlit();
          copper.move(BLTCMOD, _back.column1.bitmap.rowStride);
          copper.move(BLTDMOD, _back.column1.bitmap.rowStride);
          copper.move(BLTADAT, 0x8000);
          copper.move(BLTBDAT, 0xFFFF);
          copper.move(BLTAFWM, 0xFFFF);
          copper.move(BLTALWM, 0xFFFF);
          copper.high(BLTCPTH, _back.column1.bitmap.bitplanes);
          copper.high(BLTDPTH, _back.column1.bitmap.bitplanes);

          // Draw shapes
          for (int s = 0; s < shapes.length; ++s) {
            drawSquare(
              copper,
              _back.column1.bitmap.bitplanes + s * 8,
              _back.column1.bitmap.rowStride,
              shapes[s],
            );
            /*
            drawSquare(
              copper,
              _back.column1.bitmap.bitplanes + s * 8 + 4,
              _back.column1.bitmap.rowStride,
              mirroredShapes[s],
            );
            */
          }

          // Fill back buffer with squares
          copper ^
              (copper) {
                // fill
                for (int i = 0; i <= 0; ++i) {
                  copper <<
                      (Blit()
                        ..aPtr = _back.column1.bitmap.bitplanes + i * 4
                        ..dPtr = _back.column1.bitmap.bitplanes + i * 4
                        ..aStride = _back.column1.bitmap.bytesPerRow
                        ..dStride = _back.column1.bitmap.bytesPerRow
                        ..exclusiveFill = true
                        ..width = Kaleidoscope.squareSize >> 4
                        ..height = Kaleidoscope.squareSize * 2);
                }
                // mirror square
                for (int i = 0; i <= 31; ++i) {
                  int srcByte = i ~/ 16 * 2;
                  int destByte = srcByte + 2 - (i ~/ 8 * 2);
                  int bit = i & 15;

                  copper <<
                      (Blit()
                        ..aPtr = _back.column1.bitmap.bitplanes + srcByte
                        ..aFWM = 0x8000 >> bit
                        ..aLWM = 0
                        ..aShift = 15 - 2 * bit
                        ..cPtr = _back.column1.bitmap.bitplanes + 4 + destByte
                        ..dPtr = _back.column1.bitmap.bitplanes + 4 + destByte
                        ..aStride = _back.column1.bitmap.bytesPerRow
                        ..cStride = _back.column1.bitmap.bytesPerRow
                        ..dStride = _back.column1.bitmap.bytesPerRow
                        ..width = 2
                        ..minterms = A | C
                        ..height = Kaleidoscope.squareSize * 2);
                }
                //
                fillSprite(0, copper);
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
          ..aStride = bitmap.rowStride
          ..dPtr =
              bitmap.bitplanes + Kaleidoscope.squareSize * 2 * bitmap.rowStride
          ..dStride = bitmap.rowStride
          ..width = (bitmap.width * 2) >> 4
          ..height = bitmap.height - Kaleidoscope.squareSize * 2);
  }

  List<PartialLineBlit> _drawLine(
    Label bitplane,
    int rowStride,
    (double, double) start,
    (double, double) end,
  ) {
    var blits = <PartialLineBlit>[];

    // Turn left to right
    if (start.$1 > end.$1) {
      (start, end) = (end, start);
    }

    // If completely outside left hand side, don't draw
    if (end.$1 < 0) {
      return blits;
    }

    // If completely outside right hand side, make it a vertical line
    if (start.$1 >= Kaleidoscope.squareSize - 1) {
      start = (Kaleidoscope.squareSize - 1, start.$2 >= 0 ? start.$2 : 0);
      end = (
        Kaleidoscope.squareSize - 1,
        end.$2 <= Kaleidoscope.squareSize
            ? end.$2
            : (Kaleidoscope.squareSize).toDouble(),
      );
    }

    double getYAtX(double atX) =>
        (end.$2 - start.$2) * (atX - start.$1) / (end.$1 - start.$1) + start.$2;

    // If starting point is outside left hand side, clip it
    if (start.$1 < 0) {
      start = (0, getYAtX(0));
    }
    // If end point is outside right hand side, clip it, and draw an additional vertical line
    if (end.$1 >= Kaleidoscope.squareSize) {
      var newEndY = getYAtX(Kaleidoscope.squareSize.toDouble() - 1);
      blits = _drawLine(
        bitplane,
        rowStride,
        (Kaleidoscope.squareSize.toDouble() - 1, end.$2),
        (Kaleidoscope.squareSize.toDouble() - 1, newEndY),
      );
      end = (Kaleidoscope.squareSize.toDouble() - 1, newEndY);
    }

    // Turn top to bottom
    if (start.$2 > end.$2) {
      (start, end) = (end, start);
    }

    // If completely outside top or bottom, don't draw
    if (start.$2 > Kaleidoscope.squareSize || end.$2 < 0) {
      return blits;
    }

    double getXAtY(double atY) =>
        (end.$1 - start.$1) * (atY - start.$2) / (end.$2 - start.$2) + start.$1;

    // If starting point is outside top, clip it
    if (start.$2 < 0) {
      start = (getXAtY(0), 0);
    }
    // If end point is outside bottom, clip it
    if (end.$2 > Kaleidoscope.squareSize) {
      end = (
        getXAtY(Kaleidoscope.squareSize.toDouble()),
        Kaleidoscope.squareSize.toDouble(),
      );
    }

    var blit = drawBlitterLine(
      (
        start.$1.toInt().clamp(0, Kaleidoscope.squareSize - 1),
        start.$2.toInt(),
      ),
      (end.$1.toInt().clamp(0, Kaleidoscope.squareSize - 1), end.$2.toInt()),
      rowStride,
      bitplane,
    );

    if (blit != null) {
      blits.add(blit);
    }

    return blits;
  }

  // Draw one square
  void drawSquare(
    Copper copper,
    Label bitplanes,
    int rowStride,
    List<(double, double)> coords,
  ) {
    for (int i = 0; i < coords.length; ++i) {
      var components = _drawLine(
        bitplanes,
        rowStride,
        coords[i],
        coords[(i + 1) % coords.length],
      );

      for (var c in components) {
        copper << c;
      }
    }
  }

  PartialLineBlit? drawBlitterLine(
    (int, int) lineStart,
    (int, int) lineEnd,
    int dStride,
    Label bitplane,
  ) {
    var (startX, startY) = lineStart;
    var (endX, endY) = lineEnd;

    if (startY == endY) {
      return null;
    } else if (startY > endY) {
      (startY, endY) = (endY, startY);
      (startX, endX) = (endX, startX);
    }

    var startWord = (startY * dStride + startX ~/ 8) & ~1;

    var dy = endY - startY;
    var dx = endX - startX;

    var octant = 0;

    if (dx < 0) {
      dx = -dx;
      octant = 2;
    }

    if (dx >= 2 * dy) {
      dy -= 1;
    }

    if (dy - dx <= 0) {
      (dx, dy) = (dy, dx);
      octant += 1;
    }
    octant <<= 1;

    var twoDxMinusDy = 2 * dx - dy;
    if (twoDxMinusDy < 0) {
      octant += 1;
    }

    var octants = [0x03, 0x43, 0x13, 0x53, 0x0B, 0x4B, 0x17, 0x57];
    var bltcon0 = ((startX & 0xF) << 12) | 0x0A4A;
    var bltcon1 = octants[octant & 0xF];

    var bltaptl = twoDxMinusDy;
    var bltamod = 2 * (twoDxMinusDy - dy);
    var bltbmod = 4 * dx;
    var bltsizv = dy;

    return PartialLineBlit(
      bitplane,
      startWord, // BLTCPT, BLTDPT
      bltaptl,
      bltcon0,
      bltcon1,
      bltbmod,
      bltamod,
      (bltsizv << 6) | 2,
    );
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
            updateControlWords(sprite, h, Kaleidoscope.squareSize * 6);
          }

          var back = _kaleidoscope.backForFrame(_frame);
          clearBitmapSprite(0, back.column1);
          for (int i = 1; i <= 4; ++i) {
            updateControlWords(
              back.columns[i],
              Kaleidoscope.squareSize * 2 * i,
              Kaleidoscope.squareSize * 6,
            );
          }
        };
  }
}

class KaleidoscopeFrameFooter implements CopperComponent {
  final Kaleidoscope _kaleidoscope;
  final int _frame;

  KaleidoscopeSpriteSet get _back => _kaleidoscope.backForFrame(_frame);

  KaleidoscopeFrameFooter(this._kaleidoscope, this._frame);

  @override
  void addToCopper(Copper copper) {
    copper.wait(v: 26);
    copper.ptr(SPR1PT, _back.column1.bitmap.bitplanes);
    copper.ptr(SPR2PT, _back.column1.bitmap.bitplanes);
    copper.ptr(SPR3PT, _back.column1.bitmap.bitplanes);
    copper.ptr(SPR4PT, _back.column1.bitmap.bitplanes);
  }
}
