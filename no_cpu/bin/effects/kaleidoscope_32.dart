import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

class PartialLineBlit {
  static final dataSize = 6 * 2;

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

  void addToData(Data data) {
    data.addLow(bitplane + startWord);
    data.addWord(bltaptl);
    data.addWord(bltbmod);
    data.addWord(bltamod);
    data.addWord(bltsize);
    data.addWord((bltcon0 & 0xF000) | (bltcon1 & 0x007F));
  }

  static PartialLineBlit? draw(
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
    var bltcon0 = ((startX & 0xF) << 12) | 0x0A4A; // 4 bits
    var bltcon1 = octants[octant & 0xF]; // 7 bits

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

class PartialLineBlitComponent implements CopperComponent {
  final byteSize = 9 * 4;

  @override
  void addToCopper(Copper copper) {
    copper.waitBlit();
    copper.move(BLTCPTL, 0);
    copper.move(BLTDPTL, 0);
    copper.move(BLTAPTL, 0);
    copper.move(BLTCON0, 0);
    copper.move(BLTCON1, 0);
    copper.move(BLTBMOD, 0);
    copper.move(BLTAMOD, 0);
    copper.move(BLTSIZE, 0);
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
  static final depth = 2;
  static final squareSize = 32;
  static final maxLinesPerSquare = 12;

  late Space temp = Space(
    maxLinesPerSquare * PartialLineBlit.dataSize,
    origin: "Kaleidoscope temp",
  );

  final sprites = KaleidoscopeSpriteSet();

  Bitmap get bitmap => sprites.column1.bitmap;

  late final _effectCopper = _makeCopper();

  final int cycleLength;
  final int frameSkip;
  final int pattern1;
  final bool reversePattern1;
  final int pattern2;
  final bool reversePattern2;

  Kaleidoscope(
    this.cycleLength,
    this.frameSkip,
    this.pattern1,
    this.pattern2, {
    this.reversePattern1 = false,
    this.reversePattern2 = false,
  });

  Display displayForFrame(int frame) {
    return Display()..sprites = sprites.columns.map((e) => e.label).toList();
  }

  KaleidoscopeFrame frame(int frame) {
    return KaleidoscopeFrame(this, frame - frame % frameSkip);
  }

  KaleidoscopeFrameInit init(int frame) {
    return KaleidoscopeFrameInit(this);
  }

  KaleidoscopeFrameFooter footer(int frame) {
    return KaleidoscopeFrameFooter(this);
  }

  Copper _makeCopper() {
    var effectCopper = Copper(mutability: Mutability.local);

    // Clear the first two squares
    effectCopper <<
        (Blit()..dSetInterleaved(bitmap, h: Kaleidoscope.squareSize));

    // Prepare line draw
    effectCopper.waitBlit();
    effectCopper.move(BLTCMOD, bitmap.rowStride);
    effectCopper.move(BLTDMOD, bitmap.rowStride);
    effectCopper.move(BLTADAT, 0x8000);
    effectCopper.move(BLTBDAT, 0xFFFF);
    effectCopper.move(BLTAFWM, 0xFFFF);
    effectCopper.move(BLTALWM, 0xFFFF);
    effectCopper.high(BLTCPTH, bitmap.bitplanes);
    effectCopper.high(BLTDPTH, bitmap.bitplanes);

    // DRAW LINES
    var lineDrawStart = effectCopper.data.addLabel();
    var cptlPtr = FreeLabel("BLTCPTL");
    var dptlPtr = FreeLabel("BLTDPTL");
    var aptlPtr = FreeLabel("BLTAPTL");
    var con0Ptr = FreeLabel("BLTCON0");
    var con1Ptr = FreeLabel("BLTCON1");
    var bmodPtr = FreeLabel("BLTBMOD");
    var amodPtr = FreeLabel("BLTAMOD");
    var sizePtr = FreeLabel("BLTSIZE");

    effectCopper <<
        PartialLineBlitComponent() /
            {
              BLTCPTL: cptlPtr,
              BLTDPTL: dptlPtr,
              BLTAPTL: aptlPtr,
              BLTCON0: con0Ptr,
              BLTCON1: con1Ptr,
              BLTBMOD: bmodPtr,
              BLTAMOD: amodPtr,
              BLTSIZE: sizePtr,
            };
    var lineDrawEnd = effectCopper.data.addLabel();
    for (int i = 1; i < Kaleidoscope.maxLinesPerSquare; ++i) {
      effectCopper << PartialLineBlitComponent();
    }

    // fill
    effectCopper <<
        (Blit()
          ..aPtr = bitmap.bitplanes
          ..dPtr = bitmap.bitplanes
          ..aStride = bitmap.bytesPerRow
          ..dStride = bitmap.bytesPerRow
          ..exclusiveFill = true
          ..width = Kaleidoscope.squareSize >> 4
          ..height = Kaleidoscope.squareSize * 2);

    // mirroring temporary storage
    Bitmap mirrorTemp = Bitmap.space(
      16,
      Kaleidoscope.squareSize,
      2,
      interleaved: true,
    );

    void mirrorColumn(Label src, Label dest) {
      // Screen (src) 0000000011111111 to temp
      effectCopper <<
          (Blit()
            ..aPtr = src
            ..aStride = bitmap.bytesPerRow
            ..aFWM = 0xFF00
            ..aLWM = 0xFF00
            ..aShift = 8
            ..dSetInterleaved(mirrorTemp)
            ..width = 1
            ..height = Kaleidoscope.squareSize * 2);
      effectCopper <<
          (Blit()
            ..descending = true
            ..aPtr = src
            ..aStride = bitmap.bytesPerRow
            ..aFWM = 0x00FF
            ..aLWM = 0x00FF
            ..aShift = 8
            ..cSetInterleaved(mirrorTemp)
            ..dSetInterleaved(mirrorTemp)
            ..minterms = A | C
            ..width = 1
            ..height = Kaleidoscope.squareSize * 2);

      // Temp 0000111100001111 to screen (dest)
      effectCopper <<
          (Blit()
            ..aSetInterleaved(mirrorTemp)
            ..aFWM = 0xF0F0
            ..aLWM = 0xF0F0
            ..aShift = 4
            ..dPtr = dest
            ..dStride = bitmap.bytesPerRow
            ..width = 1
            ..height = Kaleidoscope.squareSize * 2);
      effectCopper <<
          (Blit()
            ..descending = true
            ..aSetInterleaved(mirrorTemp)
            ..aFWM = 0x0F0F
            ..aLWM = 0x0F0F
            ..aShift = 4
            ..cPtr = dest
            ..cStride = bitmap.bytesPerRow
            ..dPtr = dest
            ..dStride = bitmap.bytesPerRow
            ..minterms = A | C
            ..width = 1
            ..height = Kaleidoscope.squareSize * 2);

      // Screen (dest) 0011001100110011 to temp
      effectCopper <<
          (Blit()
            ..aPtr = dest
            ..aStride = bitmap.bytesPerRow
            ..aFWM = 0xCCCC
            ..aLWM = 0xCCCC
            ..aShift = 2
            ..dSetInterleaved(mirrorTemp)
            ..width = 1
            ..height = Kaleidoscope.squareSize * 2);
      effectCopper <<
          (Blit()
            ..descending = true
            ..aPtr = dest
            ..aStride = bitmap.bytesPerRow
            ..aFWM = 0x3333
            ..aLWM = 0x3333
            ..aShift = 2
            ..cSetInterleaved(mirrorTemp)
            ..dSetInterleaved(mirrorTemp)
            ..minterms = A | C
            ..width = 1
            ..height = Kaleidoscope.squareSize * 2);

      // Temp 0101010101010101 to screen
      effectCopper <<
          (Blit()
            ..aSetInterleaved(mirrorTemp)
            ..aFWM = 0xAAAA
            ..aLWM = 0xAAAA
            ..aShift = 1
            ..dPtr = dest
            ..dStride = bitmap.bytesPerRow
            ..width = 1
            ..height = Kaleidoscope.squareSize * 2);
      effectCopper <<
          (Blit()
            ..descending = true
            ..aSetInterleaved(mirrorTemp)
            ..aFWM = 0x5555
            ..aLWM = 0x5555
            ..aShift = 1
            ..cPtr = dest
            ..cStride = bitmap.bytesPerRow
            ..dPtr = dest
            ..dStride = bitmap.bytesPerRow
            ..minterms = A | C
            ..width = 1
            ..height = Kaleidoscope.squareSize * 2);
    }

    mirrorColumn(bitmap.bitplanes, bitmap.bitplanes + 6);
    mirrorColumn(bitmap.bitplanes + 2, bitmap.bitplanes + 4);

    // Mirror first sprite square to next one down
    effectCopper <<
        (Blit()
          ..aPtr = bitmap.bitplanes
          ..aStride = bitmap.rowStride
          ..dPtr =
              bitmap.bitplanes +
              (Kaleidoscope.squareSize * 2 - 1) * bitmap.rowStride
          ..dStride = -bitmap.rowStride
          ..width = (bitmap.width * 2) >> 4
          ..height = Kaleidoscope.squareSize);

    // First sprite square to rows below
    effectCopper <<
        (Blit()
          ..aPtr = bitmap.bitplanes
          ..aStride = bitmap.rowStride
          ..dPtr =
              bitmap.bitplanes + Kaleidoscope.squareSize * 2 * bitmap.rowStride
          ..dStride = bitmap.rowStride
          ..width = (bitmap.width * 2) >> 4
          ..height = bitmap.height - Kaleidoscope.squareSize * 2);

    // Blit line drawing words into copperlist
    Blit blitWords(int offset, Label ptr) => (Blit()
      ..aPtr = temp.label + offset
      ..dPtr = ptr
      ..aStride = PartialLineBlit.dataSize
      ..dStride = lineDrawStart ^ lineDrawEnd
      ..width = 1
      ..height = Kaleidoscope.maxLinesPerSquare);

    Blit blitCon0(int offset, Label ptr) => (Blit()
      ..aPtr = temp.label + offset
      ..aStride = PartialLineBlit.dataSize
      ..aFWM = 0xF000
      ..aLWM = 0xF000
      ..cData = 0x0A4A
      ..dPtr = ptr
      ..dStride = lineDrawStart ^ lineDrawEnd
      ..minterms = A | C
      ..width = 1
      ..height = Kaleidoscope.maxLinesPerSquare);

    Blit blitCon1(int offset, Label ptr) => (Blit()
      ..aPtr = temp.label + offset
      ..aStride = PartialLineBlit.dataSize
      ..aFWM = 0x007F
      ..aLWM = 0x007F
      ..dPtr = ptr
      ..dStride = lineDrawStart ^ lineDrawEnd
      ..width = 1
      ..height = Kaleidoscope.maxLinesPerSquare);

    var blitCopper = Copper(mutability: Mutability.local);

    // Copy line data to temp
    blitCopper <<
        (Blit()
          ..channelMask = enableA | enableD
          ..dPtr = temp.label
          ..aStride = 2
          ..dStride = 2
          ..width = 1
          ..height =
              Kaleidoscope.maxLinesPerSquare * PartialLineBlit.dataSize ~/ 2);

    // Make line blits noops by setting BLTSIZE register to NOOP
    blitCopper <<
        (Blit()
          ..aData = NOOP
          ..dPtr = sizePtr - 2
          ..dStride = lineDrawStart ^ lineDrawEnd
          ..width = 1
          ..height = Kaleidoscope.maxLinesPerSquare);

    // Make the correct number of lineblits actual blits
    var blitSizeBlitSizePtr = FreeLabel("blitSizeBlitSizePtr");
    blitCopper <<
        (Blit()
          ..aPtr = temp.label
          ..dPtr = blitSizeBlitSizePtr
          ..width = 1
          ..height = 1);

    blitCopper <<
        (Blit()
              ..aData = BLTSIZE
              ..dPtr = sizePtr - 2
              ..dStride = lineDrawStart ^ lineDrawEnd
              ..width = 1
              ..height = Kaleidoscope.maxLinesPerSquare) /
            {BLTSIZE: blitSizeBlitSizePtr};

    var lineDataStart = 2;

    blitCopper << blitWords(lineDataStart + 0, cptlPtr);
    blitCopper << blitWords(lineDataStart + 0, dptlPtr);
    blitCopper << blitWords(lineDataStart + 2, aptlPtr);
    blitCopper << blitWords(lineDataStart + 4, bmodPtr);
    blitCopper << blitWords(lineDataStart + 6, amodPtr);
    blitCopper << blitWords(lineDataStart + 8, sizePtr);
    blitCopper << blitCon0(lineDataStart + 10, con0Ptr);
    blitCopper << blitCon1(lineDataStart + 10, con1Ptr);

    blitCopper.call(effectCopper);

    return blitCopper;
  }
}

class KaleidoscopeFrame implements CopperComponent {
  final Kaleidoscope _kaleidoscope;
  final int _frame;

  KaleidoscopeFrame(this._kaleidoscope, this._frame);

  (double, double) rotate((double, double) coord, double angle) => (
    coord.$1 * cos(angle) - coord.$2 * sin(angle),
    coord.$1 * sin(angle) + coord.$2 * cos(angle),
  );

  (double, double) center((double, double) coord) => (
    coord.$1 + Kaleidoscope.squareSize ~/ 2,
    coord.$2 + Kaleidoscope.squareSize ~/ 2,
  );

  List<(double, double)> diamondCoords(bool reverse) {
    var angle = _frame / _kaleidoscope.cycleLength * (2 * pi) + 2;
    if (reverse) {
      angle = -angle;
    }

    var coords = [(-10.0, 0.0), (0.0, -20.0), (10.0, 0.0), (0.0, 20.0)];

    return coords.map((e) => rotate((e.$1, e.$2), angle)).map(center).toList();
  }

  List<(double, double)> triangleCoords(bool reverse) {
    var angle = _frame / _kaleidoscope.cycleLength * (2 * pi);
    var center = Kaleidoscope.squareSize / 2;

    if (reverse) {
      angle = -angle;
    }

    (double, double) coord(double angle) => (
      (sin(angle) * (center * 1.5)) + center,
      (cos(angle) * (center * 1.5)) + center,
    );

    return List.generate(3, (i) => coord(angle + 2 * pi * i / 3));
  }

  List<(double, double)> barCoords(bool reverse) {
    var angle = _frame / _kaleidoscope.cycleLength * (2 * pi) + 1.0;
    if (reverse) {
      angle = -angle;
    }

    var coords = [(-10.0, -50.0), (10.0, -50.0), (10.0, 50.0), (-10.0, 50.0)];

    return coords
        .map((e) => rotate(((e.$1 - 10) * 0.5, e.$2 * 0.5), angle))
        .map(center)
        .toList();
  }

  @override
  void addToCopper(Copper copper) {
    // Draw shapes
    var blits = <PartialLineBlit>[];
    var shapes = [triangleCoords, barCoords, diamondCoords];

    blits += drawSquare(
      _kaleidoscope.bitmap.bitplanes + 0 * 8,
      _kaleidoscope.bitmap.rowStride,
      shapes[_kaleidoscope.pattern1](_kaleidoscope.reversePattern1),
    );

    blits += drawSquare(
      _kaleidoscope.bitmap.bitplanes + 1 * 8,
      _kaleidoscope.bitmap.rowStride,
      shapes[_kaleidoscope.pattern2](_kaleidoscope.reversePattern2),
    );

    assert(blits.length <= Kaleidoscope.maxLinesPerSquare);
    Data data = Data(origin: this);
    data.addWord((blits.length << 6) | 1); // number of lines
    for (var b in blits) {
      b.addToData(data);
    }

    copper.waitBlit();
    copper.ptr(BLTAPT, data.label);

    copper.call(_kaleidoscope._effectCopper);
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

    var blit = PartialLineBlit.draw(
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
  List<PartialLineBlit> drawSquare(
    Label bitplanes,
    int rowStride,
    List<(double, double)> coords,
  ) {
    var blits = <PartialLineBlit>[];

    for (int i = 0; i < coords.length; ++i) {
      blits += _drawLine(
        bitplanes,
        rowStride,
        coords[i],
        coords[(i + 1) % coords.length],
      );
    }

    return blits;
  }
}

class KaleidoscopeFrameInit implements CopperComponent {
  final Kaleidoscope _kaleidoscope;

  KaleidoscopeFrameInit(this._kaleidoscope);

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

          clearBitmapSprite(0, _kaleidoscope.sprites.column1);
          for (int i = 1; i <= 4; ++i) {
            updateControlWords(
              _kaleidoscope.sprites.columns[i],
              Kaleidoscope.squareSize * 2 * i,
              Kaleidoscope.squareSize * 6,
            );
          }
        };
  }
}

class KaleidoscopeFrameFooter implements CopperComponent {
  final Kaleidoscope _kaleidoscope;

  Bitmap get bitmap => _kaleidoscope.sprites.column1.bitmap;

  KaleidoscopeFrameFooter(this._kaleidoscope);

  @override
  void addToCopper(Copper copper) {
    copper.wait(v: 26);
    copper.ptr(SPR1PT, bitmap.bitplanes);
    copper.ptr(SPR2PT, bitmap.bitplanes);
    copper.ptr(SPR3PT, bitmap.bitplanes);
    copper.ptr(SPR4PT, bitmap.bitplanes);
  }
}
