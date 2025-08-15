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
  late final Sprite column1 = Sprite.space(
    6 * Kaleidoscope._squareSize,
    alignment: 4,
  );
  late final Sprite column2 = Sprite.space(1);
  late final Sprite column3 = Sprite.space(1);
  late final Sprite column4 = Sprite.space(1);
  late final Sprite column5 = Sprite.space(1);

  late final columns = [column1, column2, column3, column4, column5];
}

class CopperEffectBitplaneVariables {
  late Space blitterTemp = Space(
    Kaleidoscope._maxLinesPerSquare * PartialLineBlit.dataSize,
    origin: this,
  );

  var cptlPtr = FreeLabel("BLTCPTL");
  var dptlPtr = FreeLabel("BLTDPTL");
  var aptlPtr = FreeLabel("BLTAPTL");
  var con0Ptr = FreeLabel("BLTCON0");
  var con1Ptr = FreeLabel("BLTCON1");
  var bmodPtr = FreeLabel("BLTBMOD");
  var amodPtr = FreeLabel("BLTAMOD");
  var sizePtr = FreeLabel("BLTSIZE");
}

class Kaleidoscope {
  // Effect parameters
  int pattern1 = 1;
  bool reversePattern1 = false;
  int pattern2 = 0;
  bool reversePattern2 = false;

  // Tunables
  static final cycleLength = 128;
  static final frameSkip = 2;

  static final _cycleFrameLength = cycleLength ~/ frameSkip;

  // Constants
  static final _squareSize = 32;
  static final _maxLinesPerSquare = 7;

  static final _sprites = KaleidoscopeSpriteSet();
  static Bitmap get _backBuffer => _sprites.column1.bitmap;

  static final _shapeLines = [
    _makeShapeFrames(_triangleCoords),
    _makeShapeFrames(_barCoords),
    _makeShapeFrames(_diamondCoords),
  ];

  late final _effectCopper = _makeCopper();

  KaleidoscopeFrame frame(int frame) {
    int frame1 = reversePattern1 ? cycleLength - frame : frame;
    int frame2 = reversePattern2 ? cycleLength - frame : frame;
    return KaleidoscopeFrame(
      this,
      frame1 % cycleLength ~/ frameSkip,
      frame2 % cycleLength ~/ frameSkip,
    );
  }

  KaleidoscopeFrameInit init(int frame) {
    return KaleidoscopeFrameInit();
  }

  Display displayForFrame(int frame) {
    return Display()..sprites = _sprites.columns.map((e) => e.label).toList();
  }

  KaleidoscopeFrameFooter footer(int frame) {
    return KaleidoscopeFrameFooter();
  }

  static Data _shapeFrame(
    int frame,
    List<(double, double)> Function(int) coords,
  ) {
    var blits = _drawSquare(
      _backBuffer.bitplanes,
      _backBuffer.rowStride,
      coords(frame),
    );

    assert(blits.length <= Kaleidoscope._maxLinesPerSquare);
    Data data = Data(origin: "Kaleidoscope");
    data.addWord((blits.length << 6) | 1); // number of lines
    for (var b in blits) {
      b.addToData(data);
    }

    return data;
  }

  static List<Data> _makeShapeFrames(
    List<(double, double)> Function(int) coords,
  ) => List.generate(
    _cycleFrameLength,
    (i) => _shapeFrame(i * frameSkip, coords),
  );

  static (double, double) _rotate((double, double) coord, double angle) => (
    coord.$1 * cos(angle) - coord.$2 * sin(angle),
    coord.$1 * sin(angle) + coord.$2 * cos(angle),
  );

  static (double, double) _center((double, double) coord) => (
    coord.$1 + Kaleidoscope._squareSize ~/ 2,
    coord.$2 + Kaleidoscope._squareSize ~/ 2,
  );

  static List<(double, double)> _diamondCoords(int frame) {
    var angle = frame / cycleLength * (2 * pi) + 0;
    var coords = [(-10.0, 0.0), (0.0, -20.0), (10.0, 0.0), (0.0, 20.0)];

    return coords
        .map((e) => _rotate((e.$1 - 5, e.$2), angle))
        .map(_center)
        .toList();
  }

  static List<(double, double)> _triangleCoords(int frame) {
    var angle = frame / cycleLength * (2 * pi);
    var center = Kaleidoscope._squareSize / 2;

    (double, double) coord(double angle) => (
      (sin(angle) * (center * 1.5)) + center,
      (cos(angle) * (center * 1.5)) + center,
    );

    return List.generate(3, (i) => coord(angle + 2 * pi * i / 3));
  }

  static List<(double, double)> _barCoords(int frame) {
    var angle = frame / cycleLength * (2 * pi) + 1.0;
    var coords = [(-10.0, -50.0), (10.0, -50.0), (10.0, 50.0), (-10.0, 50.0)];

    return coords
        .map((e) => _rotate(((e.$1 - 10) * 0.5, e.$2 * 0.5), angle))
        .map(_center)
        .toList();
  }

  static List<PartialLineBlit> _drawLine(
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
    if (start.$1 >= Kaleidoscope._squareSize - 1) {
      start = (Kaleidoscope._squareSize - 1, start.$2 >= 0 ? start.$2 : 0);
      end = (
        Kaleidoscope._squareSize - 1,
        end.$2 <= Kaleidoscope._squareSize
            ? end.$2
            : (Kaleidoscope._squareSize).toDouble(),
      );
    }

    double getYAtX(double atX) =>
        (end.$2 - start.$2) * (atX - start.$1) / (end.$1 - start.$1) + start.$2;

    // If starting point is outside left hand side, clip it
    if (start.$1 < 0) {
      start = (0, getYAtX(0));
    }
    // If end point is outside right hand side, clip it, and draw an additional vertical line
    if (end.$1 >= Kaleidoscope._squareSize) {
      var newEndY = getYAtX(Kaleidoscope._squareSize.toDouble() - 1);
      blits = _drawLine(
        bitplane,
        rowStride,
        (Kaleidoscope._squareSize.toDouble() - 1, end.$2),
        (Kaleidoscope._squareSize.toDouble() - 1, newEndY),
      );
      end = (Kaleidoscope._squareSize.toDouble() - 1, newEndY);
    }

    // Turn top to bottom
    if (start.$2 > end.$2) {
      (start, end) = (end, start);
    }

    // If completely outside top or bottom, don't draw
    if (start.$2 > Kaleidoscope._squareSize || end.$2 < 0) {
      return blits;
    }

    double getXAtY(double atY) =>
        (end.$1 - start.$1) * (atY - start.$2) / (end.$2 - start.$2) + start.$1;

    // If starting point is outside top, clip it
    if (start.$2 < 0) {
      start = (getXAtY(0), 0);
    }
    // If end point is outside bottom, clip it
    if (end.$2 > Kaleidoscope._squareSize) {
      end = (
        getXAtY(Kaleidoscope._squareSize.toDouble()),
        Kaleidoscope._squareSize.toDouble(),
      );
    }

    var blit = PartialLineBlit.draw(
      (
        start.$1.toInt().clamp(0, Kaleidoscope._squareSize - 1),
        start.$2.toInt(),
      ),
      (end.$1.toInt().clamp(0, Kaleidoscope._squareSize - 1), end.$2.toInt()),
      rowStride,
      bitplane,
    );

    if (blit != null) {
      blits.add(blit);
    }

    return blits;
  }

  // Draw one square
  static List<PartialLineBlit> _drawSquare(
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

  Copper _makeCopper() {
    var plane0 = CopperEffectBitplaneVariables();
    var plane1 = CopperEffectBitplaneVariables();

    var effectCopper = Copper(mutability: Mutability.local);

    // Clear the first two squares
    effectCopper <<
        (Blit()..dSetInterleaved(_backBuffer, h: Kaleidoscope._squareSize));

    // Prepare line draw
    effectCopper.waitBlit();
    effectCopper.move(BLTCMOD, _backBuffer.rowStride);
    effectCopper.move(BLTDMOD, _backBuffer.rowStride);
    effectCopper.move(BLTADAT, 0x8000);
    effectCopper.move(BLTBDAT, 0xFFFF);
    effectCopper.move(BLTAFWM, 0xFFFF);
    effectCopper.move(BLTALWM, 0xFFFF);
    effectCopper.high(BLTCPTH, _backBuffer.bitplanes);
    effectCopper.high(BLTDPTH, _backBuffer.bitplanes);

    // DRAW LINES, plane 0
    var lineDrawStart1 = effectCopper.data.addLabel();

    effectCopper <<
        PartialLineBlitComponent() /
            {
              BLTCPTL: plane0.cptlPtr,
              BLTDPTL: plane0.dptlPtr,
              BLTAPTL: plane0.aptlPtr,
              BLTCON0: plane0.con0Ptr,
              BLTCON1: plane0.con1Ptr,
              BLTBMOD: plane0.bmodPtr,
              BLTAMOD: plane0.amodPtr,
              BLTSIZE: plane0.sizePtr,
            };
    var lineDrawEnd1 = effectCopper.data.addLabel();
    for (int i = 1; i < Kaleidoscope._maxLinesPerSquare; ++i) {
      effectCopper << PartialLineBlitComponent();
    }

    // DRAW LINES, plane 1
    //var lineDrawStart2 = effectCopper.data.addLabel();
    effectCopper <<
        PartialLineBlitComponent() /
            {
              BLTCPTL: plane1.cptlPtr,
              BLTDPTL: plane1.dptlPtr,
              BLTAPTL: plane1.aptlPtr,
              BLTCON0: plane1.con0Ptr,
              BLTCON1: plane1.con1Ptr,
              BLTBMOD: plane1.bmodPtr,
              BLTAMOD: plane1.amodPtr,
              BLTSIZE: plane1.sizePtr,
            };
    for (int i = 1; i < Kaleidoscope._maxLinesPerSquare; ++i) {
      effectCopper << PartialLineBlitComponent();
    }

    // fill
    effectCopper <<
        (Blit()
          ..aPtr = _backBuffer.bitplanes
          ..dPtr = _backBuffer.bitplanes
          ..aStride = _backBuffer.bytesPerRow
          ..dStride = _backBuffer.bytesPerRow
          ..exclusiveFill = true
          ..width = Kaleidoscope._squareSize >> 4
          ..height = Kaleidoscope._squareSize * 2);

    // mirroring temporary storage
    Bitmap mirrorTemp = Bitmap.space(
      16,
      Kaleidoscope._squareSize,
      2,
      interleaved: true,
    );

    void mirrorColumn(Label src, Label dest) {
      // Screen (src) 0000000011111111 to temp
      effectCopper <<
          (Blit()
            ..aPtr = src
            ..aStride = _backBuffer.bytesPerRow
            ..aFWM = 0xFF00
            ..aLWM = 0xFF00
            ..aShift = 8
            ..dSetInterleaved(mirrorTemp)
            ..width = 1
            ..height = Kaleidoscope._squareSize * 2);
      effectCopper <<
          (Blit()
            ..descending = true
            ..aPtr = src
            ..aStride = _backBuffer.bytesPerRow
            ..aFWM = 0x00FF
            ..aLWM = 0x00FF
            ..aShift = 8
            ..cSetInterleaved(mirrorTemp)
            ..dSetInterleaved(mirrorTemp)
            ..minterms = A | C
            ..width = 1
            ..height = Kaleidoscope._squareSize * 2);

      // Temp 0000111100001111 to screen (dest)
      effectCopper <<
          (Blit()
            ..aSetInterleaved(mirrorTemp)
            ..aFWM = 0xF0F0
            ..aLWM = 0xF0F0
            ..aShift = 4
            ..dPtr = dest
            ..dStride = _backBuffer.bytesPerRow
            ..width = 1
            ..height = Kaleidoscope._squareSize * 2);
      effectCopper <<
          (Blit()
            ..descending = true
            ..aSetInterleaved(mirrorTemp)
            ..aFWM = 0x0F0F
            ..aLWM = 0x0F0F
            ..aShift = 4
            ..cPtr = dest
            ..cStride = _backBuffer.bytesPerRow
            ..dPtr = dest
            ..dStride = _backBuffer.bytesPerRow
            ..minterms = A | C
            ..width = 1
            ..height = Kaleidoscope._squareSize * 2);

      // Screen (dest) 0011001100110011 to temp
      effectCopper <<
          (Blit()
            ..aPtr = dest
            ..aStride = _backBuffer.bytesPerRow
            ..aFWM = 0xCCCC
            ..aLWM = 0xCCCC
            ..aShift = 2
            ..dSetInterleaved(mirrorTemp)
            ..width = 1
            ..height = Kaleidoscope._squareSize * 2);
      effectCopper <<
          (Blit()
            ..descending = true
            ..aPtr = dest
            ..aStride = _backBuffer.bytesPerRow
            ..aFWM = 0x3333
            ..aLWM = 0x3333
            ..aShift = 2
            ..cSetInterleaved(mirrorTemp)
            ..dSetInterleaved(mirrorTemp)
            ..minterms = A | C
            ..width = 1
            ..height = Kaleidoscope._squareSize * 2);

      // Temp 0101010101010101 to screen
      effectCopper <<
          (Blit()
            ..aSetInterleaved(mirrorTemp)
            ..aFWM = 0xAAAA
            ..aLWM = 0xAAAA
            ..aShift = 1
            ..dPtr = dest
            ..dStride = _backBuffer.bytesPerRow
            ..width = 1
            ..height = Kaleidoscope._squareSize * 2);
      effectCopper <<
          (Blit()
            ..descending = true
            ..aSetInterleaved(mirrorTemp)
            ..aFWM = 0x5555
            ..aLWM = 0x5555
            ..aShift = 1
            ..cPtr = dest
            ..cStride = _backBuffer.bytesPerRow
            ..dPtr = dest
            ..dStride = _backBuffer.bytesPerRow
            ..minterms = A | C
            ..width = 1
            ..height = Kaleidoscope._squareSize * 2);
    }

    mirrorColumn(_backBuffer.bitplanes, _backBuffer.bitplanes + 6);
    mirrorColumn(_backBuffer.bitplanes + 2, _backBuffer.bitplanes + 4);

    // Mirror first sprite square to next one down
    effectCopper <<
        (Blit()
          ..aPtr = _backBuffer.bitplanes
          ..aStride = _backBuffer.rowStride
          ..dPtr =
              _backBuffer.bitplanes +
              (Kaleidoscope._squareSize * 2 - 1) * _backBuffer.rowStride
          ..dStride = -_backBuffer.rowStride
          ..width = (_backBuffer.width * 2) >> 4
          ..height = Kaleidoscope._squareSize);

    // First sprite square to rows below
    effectCopper <<
        (Blit()
          ..aPtr = _backBuffer.bitplanes
          ..aStride = _backBuffer.rowStride
          ..dPtr =
              _backBuffer.bitplanes +
              Kaleidoscope._squareSize * 2 * _backBuffer.rowStride
          ..dStride = _backBuffer.rowStride
          ..width = (_backBuffer.width * 2) >> 4
          ..height = _backBuffer.height - Kaleidoscope._squareSize * 2);

    // Blit line drawing words into copperlist
    Blit blitWords(Label src, Label dest, {int ptrAdjust = 0}) {
      var blit = Blit()
        ..aPtr = src
        ..dPtr = dest
        ..aStride = PartialLineBlit.dataSize
        ..dStride = lineDrawStart1 ^ lineDrawEnd1
        ..width = 1
        ..height = Kaleidoscope._maxLinesPerSquare;

      if (ptrAdjust != 0) {
        blit.cData = ptrAdjust;
        blit.minterms = A | C;
      }

      return blit;
    }

    Blit blitCon0(Label src, Label dest) => (Blit()
      ..aPtr = src
      ..aStride = PartialLineBlit.dataSize
      ..aFWM = 0xF000
      ..aLWM = 0xF000
      ..cData = 0x0A4A
      ..dPtr = dest
      ..dStride = lineDrawStart1 ^ lineDrawEnd1
      ..minterms = A | C
      ..width = 1
      ..height = Kaleidoscope._maxLinesPerSquare);

    Blit blitCon1(Label src, Label dest) => (Blit()
      ..aPtr = src
      ..aStride = PartialLineBlit.dataSize
      ..aFWM = 0x007F
      ..aLWM = 0x007F
      ..dPtr = dest
      ..dStride = lineDrawStart1 ^ lineDrawEnd1
      ..width = 1
      ..height = Kaleidoscope._maxLinesPerSquare);

    // The first copper, which sets up the blits for the second effect copper

    var blitCopper = Copper(mutability: Mutability.local);

    // Copy line data to temp
    blitCopper <<
        (Blit()
          ..channelMask = enableA | enableD
          ..dPtr = plane0.blitterTemp.label
          ..aStride = 2
          ..dStride = 2
          ..width = 1
          ..height =
              Kaleidoscope._maxLinesPerSquare * PartialLineBlit.dataSize ~/ 2);

    blitCopper <<
        (Blit()
          ..channelMask = enableB | enableD
          ..dPtr = plane1.blitterTemp.label
          ..aStride = 2
          ..dStride = 2
          ..width = 1
          ..height =
              Kaleidoscope._maxLinesPerSquare * PartialLineBlit.dataSize ~/ 2);

    void copyLineBlitParameters(
      CopperEffectBitplaneVariables plane, {
      int ptrAdjust = 0,
    }) {
      final lineDataStart = 2;

      // Make line blits noops by setting BLTSIZE register to NOOP
      blitCopper <<
          (Blit()
            ..aData = NOOP
            ..dPtr = plane.sizePtr - 2
            ..dStride =
                lineDrawStart1 ^
                lineDrawEnd1 // same stride for both planes
            ..width = 1
            ..height = Kaleidoscope._maxLinesPerSquare);

      // Make the correct number of lineblits actual blits
      var blitSizeBlitSizePtr = FreeLabel("blitSizeBlitSizePtr");
      blitCopper <<
          (Blit()
            ..aPtr = plane.blitterTemp.label
            ..dPtr = blitSizeBlitSizePtr
            ..width = 1
            ..height = 1);

      blitCopper <<
          (Blit()
                ..aData = BLTSIZE
                ..dPtr = plane.sizePtr - 2
                ..dStride =
                    lineDrawStart1 ^
                    lineDrawEnd1 // same stride for both planes
                ..width = 1
                ..height = Kaleidoscope._maxLinesPerSquare) /
              {BLTSIZE: blitSizeBlitSizePtr};

      Label src = plane.blitterTemp.label;
      blitCopper <<
          blitWords(
            src + lineDataStart + 0,
            plane.cptlPtr,
            ptrAdjust: ptrAdjust,
          );
      blitCopper <<
          blitWords(
            src + lineDataStart + 0,
            plane.dptlPtr,
            ptrAdjust: ptrAdjust,
          );
      blitCopper << blitWords(src + lineDataStart + 2, plane.aptlPtr);
      blitCopper << blitWords(src + lineDataStart + 4, plane.bmodPtr);
      blitCopper << blitWords(src + lineDataStart + 6, plane.amodPtr);
      blitCopper << blitWords(src + lineDataStart + 8, plane.sizePtr);
      blitCopper << blitCon0(src + lineDataStart + 10, plane.con0Ptr);
      blitCopper << blitCon1(src + lineDataStart + 10, plane.con1Ptr);
    }

    copyLineBlitParameters(plane0);
    copyLineBlitParameters(plane1, ptrAdjust: 0x0008);

    blitCopper.call(effectCopper);

    return blitCopper;
  }
}

class KaleidoscopeFrame implements CopperComponent {
  final Kaleidoscope _kaleidoscope;
  final int _frame1;
  final int _frame2;

  KaleidoscopeFrame(this._kaleidoscope, this._frame1, this._frame2);

  @override
  void addToCopper(Copper copper) {
    Data data1 = Kaleidoscope._shapeLines[_kaleidoscope.pattern1][_frame1];
    Data data2 = Kaleidoscope._shapeLines[_kaleidoscope.pattern2][_frame2];
    copper.waitBlit();
    copper.ptr(BLTAPT, data1.label);
    copper.ptr(BLTBPT, data2.label);

    copper.call(_kaleidoscope._effectCopper);
  }
}

class KaleidoscopeFrameInit implements CopperComponent {
  KaleidoscopeFrameInit();

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
            updateControlWords(sprite, h, Kaleidoscope._squareSize * 6);
          }

          clearBitmapSprite(0, Kaleidoscope._sprites.column1);
          for (int i = 1; i <= 4; ++i) {
            updateControlWords(
              Kaleidoscope._sprites.columns[i],
              Kaleidoscope._squareSize * 2 * i,
              Kaleidoscope._squareSize * 6,
            );
          }
        };
  }
}

class KaleidoscopeFrameFooter implements CopperComponent {
  Bitmap get bitmap => Kaleidoscope._sprites.column1.bitmap;

  KaleidoscopeFrameFooter();

  @override
  void addToCopper(Copper copper) {
    copper.wait(v: 26);
    copper.ptr(SPR1PT, bitmap.bitplanes);
    copper.ptr(SPR2PT, bitmap.bitplanes);
    copper.ptr(SPR3PT, bitmap.bitplanes);
    copper.ptr(SPR4PT, bitmap.bitplanes);
  }
}
