import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

// This class holds the data necessary to build the data structure for one
// line.
class PartialLineBlit {
  static final dataSize = 6 * 2;

  final Label bitplane;
  final int startWord; // Low word of BLTCPT, BLTDPT
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
    // shove bltcon0 and bltcon1 into one word
    data.addWord((bltcon0 & 0xF000) | (bltcon1 & 0x007F));
  }

  // Lowlevel "draw" a line - return the blitter register values necessary
  // to modify for this line, assuming the ones common to all lines have been
  // set up.
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
      octant += 4;
    }

    if (dx >= 2 * dy) {
      dy -= 1;
    }

    if (dy - dx <= 0) {
      (dx, dy) = (dy, dx);
      octant += 2;
    }

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

// PartialLineBlitComponent is a dummy class that only serves to add the
// necessary registers to the copper list which will draw the line. This
// could have been an AdhocCopperComponent, but it's used twice, so it isn't.
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

// PartialLineBlitVariables holds pointers to a bitplane's partial line blit
// register contents.
class PartialLineBlitVariables {
  late Space blitterTemp = Space(
    Kaleidoscope._maxLinesPerSquare * PartialLineBlit.dataSize,
    origin: this,
  );

  late var cptlPtr = FreeLabel("BLTCPTL");
  late var dptlPtr = FreeLabel("BLTDPTL");
  late var aptlPtr = FreeLabel("BLTAPTL");
  late var con0Ptr = FreeLabel("BLTCON0");
  late var con1Ptr = FreeLabel("BLTCON1");
  late var bmodPtr = FreeLabel("BLTBMOD");
  late var amodPtr = FreeLabel("BLTAMOD");
  late var sizePtr = FreeLabel("BLTSIZE");

  late var varMap = {
    BLTCPTL: cptlPtr,
    BLTDPTL: dptlPtr,
    BLTAPTL: aptlPtr,
    BLTCON0: con0Ptr,
    BLTCON1: con1Ptr,
    BLTBMOD: bmodPtr,
    BLTAMOD: amodPtr,
    BLTSIZE: sizePtr,
  };
}

// The main kaleidoscope effect class
class Kaleidoscope {
  // Effect parameters
  int pattern1 = 1;
  bool reversePattern1 = false;
  int pattern2 = 0;
  bool reversePattern2 = false;

  // Tunables
  static final cycleLength = 128;
  static final frameSkip = 1;

  static final _cycleFrameLength = cycleLength ~/ frameSkip;

  // Constants
  static final _squareSize = 32;
  static final _maxLinesPerSquare = 7;

  static final _sprites = [
    Sprite.space(6 * Kaleidoscope._squareSize),
    Sprite.space(1),
    Sprite.space(1),
    Sprite.space(1),
    Sprite.space(1),
  ];

  static Bitmap get _backBuffer => _sprites[0].bitmap;

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
    return Display()..sprites = _sprites.map((e) => e.label).toList();
  }

  KaleidoscopeFrameFooter footer(int frame) {
    return KaleidoscopeFrameFooter();
  }

  // Create the data block for one frame of a shape's animation.
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

  // Make all the data blocks for a complete cycle for one shape
  static List<Data> _makeShapeFrames(
    List<(double, double)> Function(int) coords,
  ) => List.generate(
    _cycleFrameLength,
    (i) => _shapeFrame(i * frameSkip, coords),
  );

  // 2D rotate helper
  static (double, double) _rotate((double, double) coord, double angle) => (
    coord.$1 * cos(angle) - coord.$2 * sin(angle),
    coord.$1 * sin(angle) + coord.$2 * cos(angle),
  );

  // 2D center helper
  static (double, double) _center((double, double) coord) => (
    coord.$1 + Kaleidoscope._squareSize ~/ 2,
    coord.$2 + Kaleidoscope._squareSize ~/ 2,
  );

  // Create the coordinates of the diamond shape for a specific frame
  static List<(double, double)> _diamondCoords(int frame) {
    var angle = frame / cycleLength * (2 * pi) + 0;
    var coords = [(-10.0, 0.0), (0.0, -20.0), (10.0, 0.0), (0.0, 20.0)];

    return coords
        .map((e) => _rotate((e.$1 - 5, e.$2), angle))
        .map(_center)
        .toList();
  }

  // Create the coordinates of the triangle shape for a specific frame
  static List<(double, double)> _triangleCoords(int frame) {
    var angle = frame / cycleLength * (2 * pi);
    var center = Kaleidoscope._squareSize / 2;

    (double, double) coord(double angle) => (
      (sin(angle) * (center * 1.5)) + center,
      (cos(angle) * (center * 1.5)) + center,
    );

    return List.generate(3, (i) => coord(angle + 2 * pi * i / 3));
  }

  // Create the coordinates of the bar shape for a specific frame
  static List<(double, double)> _barCoords(int frame) {
    var angle = frame / cycleLength * (2 * pi) + 1.0;
    var coords = [(-10.0, -50.0), (10.0, -50.0), (10.0, 50.0), (-10.0, 50.0)];

    return coords
        .map((e) => _rotate(((e.$1 - 10) * 0.5, e.$2 * 0.5), angle))
        .map(_center)
        .toList();
  }

  // Clip and "draw" a line. Two partial lines may be returned, if necessary
  // for blitter filling.
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

  // Create all the partial line blits for one string of coordinates of a
  // polygon.
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
    var plane0 = PartialLineBlitVariables();
    var plane1 = PartialLineBlitVariables();

    var effectCopper = Copper(
      mutability: Mutability.local,
      origin: "Kaleidoscope effect",
    );

    // Clear the first two squares
    effectCopper <<
        (Blit()..dSetInterleaved(_backBuffer, h: Kaleidoscope._squareSize));

    // Prepare the initial line draw blitter registers
    effectCopper.waitBlit();
    effectCopper.move(BLTCMOD, _backBuffer.rowStride);
    effectCopper.move(BLTDMOD, _backBuffer.rowStride);
    effectCopper.move(BLTADAT, 0x8000);
    effectCopper.move(BLTBDAT, 0xFFFF);
    effectCopper.move(BLTAFWM, 0xFFFF);
    effectCopper.move(BLTALWM, 0xFFFF);
    effectCopper.high(BLTCPTH, _backBuffer.bitplanes);
    effectCopper.high(BLTDPTH, _backBuffer.bitplanes);

    // Partial draw line blits, plane 0
    var lineDrawStart1 = effectCopper.data.addLabel();

    effectCopper << PartialLineBlitComponent() / plane0.varMap;
    var lineDrawEnd1 = effectCopper.data.addLabel();
    for (int i = 1; i < Kaleidoscope._maxLinesPerSquare; ++i) {
      effectCopper << PartialLineBlitComponent();
    }

    // Partial draw line blits, plane 1
    effectCopper << PartialLineBlitComponent() / plane1.varMap;
    for (int i = 1; i < Kaleidoscope._maxLinesPerSquare; ++i) {
      effectCopper << PartialLineBlitComponent();
    }

    // Fill blit
    effectCopper <<
        (Blit()
          ..aPtr = _backBuffer.bitplanes
          ..dPtr = _backBuffer.bitplanes
          ..aStride = _backBuffer.bytesPerRow
          ..dStride = _backBuffer.bytesPerRow
          ..exclusiveFill = true
          ..width = Kaleidoscope._squareSize >> 4
          ..height = Kaleidoscope._squareSize * 2);

    // Temporary storage for mirroring
    Bitmap mirrorTemp = Bitmap.space(
      16,
      Kaleidoscope._squareSize,
      2,
      interleaved: true,
    );

    // Mirror the bits in a one word wide column.
    void mirrorColumn(Label src, Label dest) {
      // Mirror some bits by shifting some left and some right.
      void mirrorBits(
        Label src,
        int srcBytesPerRow,
        Label dest,
        int destBytesPerRow,
        int shift,
        int mask,
      ) {
        effectCopper <<
            (Blit()
              ..aPtr = src
              ..aStride = srcBytesPerRow
              ..aFWM = mask
              ..aLWM = mask
              ..aShift = shift
              ..dPtr = dest
              ..dStride = destBytesPerRow
              ..width = 1
              ..height = Kaleidoscope._squareSize * 2);
        effectCopper <<
            (Blit()
              ..descending = true
              ..aPtr = src
              ..aStride = srcBytesPerRow
              ..aFWM = ~mask
              ..aLWM = ~mask
              ..aShift = shift
              ..cPtr = dest
              ..cStride = destBytesPerRow
              ..dPtr = dest
              ..dStride = destBytesPerRow
              ..minterms = A | C
              ..width = 1
              ..height = Kaleidoscope._squareSize * 2);
      }

      // Screen (src) 0000000011111111 to temp
      mirrorBits(
        src,
        _backBuffer.bytesPerRow,
        mirrorTemp.bitplanes,
        mirrorTemp.bytesPerRow,
        8,
        0xFF00,
      );

      // Temp 0000111100001111 to screen (dest)
      mirrorBits(
        mirrorTemp.bitplanes,
        mirrorTemp.bytesPerRow,
        dest,
        _backBuffer.bytesPerRow,
        4,
        0xF0F0,
      );

      // Screen (dest) 0011001100110011 to temp
      mirrorBits(
        dest,
        _backBuffer.bytesPerRow,
        mirrorTemp.bitplanes,
        mirrorTemp.bytesPerRow,
        2,
        0xCCCC,
      );

      // Temp 0101010101010101 to screen
      mirrorBits(
        mirrorTemp.bitplanes,
        mirrorTemp.bytesPerRow,
        dest,
        _backBuffer.bytesPerRow,
        1,
        0xAAAA,
      );
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

    // Copy first sprite square to rows below
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

    // Blit line drawing words into copperlist. This modifies another copper
    // list.
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

    // Unpack the bltcon0 words.
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

    // Unpack the bltcon1 words.
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
    var blitCopper = Copper(
      mutability: Mutability.local,
      origin: "Kaleidoscope blits",
    );

    // Copy line data to temp for plane0
    blitCopper <<
        (Blit()
          ..channelMask = enableA | enableD
          ..dPtr = plane0.blitterTemp.label
          ..aStride = 2
          ..dStride = 2
          ..width = 1
          ..height =
              Kaleidoscope._maxLinesPerSquare * PartialLineBlit.dataSize ~/ 2);

    // Copy line data to temp for plane1
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
      PartialLineBlitVariables plane, {
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

      // Copy the rest of the line drawing registers
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

          clearBitmapSprite(0, Kaleidoscope._sprites[0]);
          for (int i = 1; i <= 4; ++i) {
            updateControlWords(
              Kaleidoscope._sprites[i],
              Kaleidoscope._squareSize * 2 * i,
              Kaleidoscope._squareSize * 6,
            );
          }
        };
  }
}

class KaleidoscopeFrameFooter implements CopperComponent {
  Bitmap get bitmap => Kaleidoscope._sprites[0].bitmap;

  KaleidoscopeFrameFooter();

  @override
  void addToCopper(Copper copper) {
    copper.wait(v: 26);
    copper.ptr(SPR1PT, bitmap.bitplanes);
    copper.ptr(SPR2PT, bitmap.bitplanes);
    copper.ptr(SPR3PT, bitmap.bitplanes);
    copper.ptr(SPR4PT, bitmap.bitplanes);
  }

  @override
  String toString() => "KaleidoscopeFrameFooter";
}
