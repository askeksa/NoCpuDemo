import 'package:collection/collection.dart';

import 'copper.dart';
import 'custom.dart';
import 'memory.dart';

// Channel enable constants
const int enableA = 0x8;
const int enableB = 0x4;
const int enableC = 0x2;
const int enableD = 0x1;

// Minterm constants
const int A = 0xF0;
const int B = 0xCC;
const int C = 0xAA;
const int NANBNC = 0x01;
const int NANBC = 0x02;
const int NABNC = 0x04;
const int NABC = 0x08;
const int ANBNC = 0x10;
const int ANBC = 0x20;
const int ABNC = 0x40;
const int ABC = 0x80;

abstract class BaseBlit implements CopperComponent {
  @override
  void addToCopper(Copper copper);
}

/// A rectangular blit.
class Blit extends BaseBlit {
  /// Channel DMA pointers to the beginning of the first row.
  Label? aPtr, bPtr, cPtr, dPtr;

  /// Distances in bytes from the beginning of one row to the next.
  /// Defaults to `width * 2` (corresponding to modulo 0 in ascending mode).
  int? aStride, bStride, cStride, dStride;

  /// Immediate input channel data.
  int? aData, bData, cData;

  /// A and B channel shift values.
  int aShift = 0, bShift = 0;

  /// A channel first and last word masks.
  int aFWM = 0xFFFF, aLWM = 0xFFFF;

  /// Channel DMA enable mask. Bit order: ABCD.
  /// Defaults to the channels that have pointers specified.
  int? channelMask;

  /// Logical function minterms. Defaults to the exclusive or between all
  /// source channels that are either enabled or have data specified.
  int? minterms;

  /// Descending mode. Pointers and modulos are automatically adjusted.
  bool descending = false;

  /// Exclusive fill. Descending mode is automatically enabled.
  bool exclusiveFill = false;

  /// Inclusive fill. Descending mode is automatically enabled.
  bool inclusiveFill = false;

  /// Width (in words) and height (in rows) of the blit operation.
  /// Both default to 1.
  int? width, height;

  /// Whether the A channel mask registers should be written.
  ///
  /// Defaults to `true` if any of the following conditions are met:
  /// - The A channel is enabled.
  /// - The A data is set.
  /// - The logic function depends on A (the upper nibble of the minterms
  ///   differs from the lower nibble).
  /// - Any of the masks ([aFWM], [aLWM]) are changed from their default
  ///   values (0xFFFF).
  bool? emitMasks;

  /// Whether the modulo registers should be written for enabled channels.
  ///
  /// Defaults to `true` if the height of the blit is greater than 1.
  bool? emitModulos;

  // Shorthands for setting multiple pointers.
  set abPtr(Label value) => aPtr = bPtr = value;
  set acPtr(Label value) => aPtr = cPtr = value;
  set adPtr(Label value) => aPtr = dPtr = value;
  set bcPtr(Label value) => bPtr = cPtr = value;
  set bdPtr(Label value) => bPtr = dPtr = value;
  set cdPtr(Label value) => cPtr = dPtr = value;
  set abcPtr(Label value) => aPtr = bPtr = cPtr = value;
  set abdPtr(Label value) => aPtr = bPtr = dPtr = value;
  set acdPtr(Label value) => aPtr = cPtr = dPtr = value;
  set bcdPtr(Label value) => bPtr = cPtr = dPtr = value;
  set abcdPtr(Label value) => aPtr = bPtr = cPtr = dPtr = value;

  // Shorthands for setting multiple strides.
  set abStride(int value) => aStride = bStride = value;
  set acStride(int value) => aStride = cStride = value;
  set adStride(int value) => aStride = dStride = value;
  set bcStride(int value) => bStride = cStride = value;
  set bdStride(int value) => bStride = dStride = value;
  set cdStride(int value) => cStride = dStride = value;
  set abcStride(int value) => aStride = bStride = cStride = value;
  set abdStride(int value) => aStride = bStride = dStride = value;
  set acdStride(int value) => aStride = cStride = dStride = value;
  set bcdStride(int value) => bStride = cStride = dStride = value;
  set abcdStride(int value) => aStride = bStride = cStride = dStride = value;

  // Shorthands for setting multiple data values.
  set abData(int value) => aData = bData = value;
  set acData(int value) => aData = cData = value;
  set bcData(int value) => bData = cData = value;
  set abcData(int value) => aData = bData = cData = value;

  // Shorthand for setting multiple shift values.
  set abShift(int value) => aShift = bShift = value;

  @override
  void addToCopper(Copper copper) {
    int channelMask =
        this.channelMask ??
        (aPtr != null ? enableA : 0) |
            (bPtr != null ? enableB : 0) |
            (cPtr != null ? enableC : 0) |
            (dPtr != null ? enableD : 0);
    bool aEnabled = channelMask & enableA != 0;
    bool bEnabled = channelMask & enableB != 0;
    bool cEnabled = channelMask & enableC != 0;
    bool dEnabled = channelMask & enableD != 0;

    bool aInput = aEnabled || aData != null;
    bool bInput = bEnabled || bData != null;
    bool cInput = cEnabled || cData != null;
    int defaultLogic = (aInput ? A : 0) ^ (bInput ? B : 0) ^ (cInput ? C : 0);
    int minterms = (this.minterms ?? defaultLogic) & 0xFF;
    bool dependsOnA = (minterms >> 4) != (minterms & 0x0F);

    bool useDescending = exclusiveFill | inclusiveFill | descending;
    int width = this.width ?? 1;
    int height = this.height ?? 1;

    int ptrOffset = useDescending ? width * 2 - 2 : 0;
    int stride2modulo(int? stride) {
      stride ??= width * 2;
      return (useDescending ? -stride : stride) - width * 2;
    }

    bool emitMasks =
        this.emitMasks ??
        aInput || dependsOnA || aFWM != 0xFFFF || aLWM != 0xFFFF;

    bool emitModulos = this.emitModulos ?? height > 1;

    int bltcon0 = (aShift << 12) | (channelMask << 8) | minterms;
    int bltcon1 =
        (bShift << 12) |
        (exclusiveFill ? 0x0010 : 0) |
        (inclusiveFill ? 0x0008 : 0) |
        ((inclusiveFill | inclusiveFill | useDescending) ? 0x0002 : 0);

    copper.waitBlit();
    copper.move(BLTCON0, bltcon0);
    copper.move(BLTCON1, bltcon1);
    if (emitMasks) {
      copper.move(BLTAFWM, useDescending ? aLWM : aFWM);
      copper.move(BLTALWM, useDescending ? aFWM : aLWM);
    }
    if (cPtr != null) copper.ptr(BLTCPT, cPtr! + ptrOffset);
    if (bPtr != null) copper.ptr(BLTBPT, bPtr! + ptrOffset);
    if (aPtr != null) copper.ptr(BLTAPT, aPtr! + ptrOffset);
    if (dPtr != null) copper.ptr(BLTDPT, dPtr! + ptrOffset);
    if (emitModulos) {
      if (cEnabled) copper.move(BLTCMOD, stride2modulo(cStride));
      if (bEnabled) copper.move(BLTBMOD, stride2modulo(bStride));
      if (aEnabled) copper.move(BLTAMOD, stride2modulo(aStride));
      if (dEnabled) copper.move(BLTDMOD, stride2modulo(dStride));
    }
    if (cData != null) copper.move(BLTCDAT, cData!);
    if (bData != null) copper.move(BLTBDAT, bData!);
    if (aData != null) copper.move(BLTADAT, aData!);
    if (width <= 64 && height <= 1024) {
      copper.move(BLTSIZE, ((height & 1023) << 6) | (width & 63));
    } else {
      assert(width <= 2048);
      assert(height <= 32768);
      copper.move(BLTSIZV, height);
      copper.move(BLTSIZH, width);
    }

    // Require target to be mutable.
    dPtr?.assertMutable();
  }

  @override
  String toString() {
    var channels = <String>[
      if (aPtr != null) "A",
      if (bPtr != null) "B",
      if (cPtr != null) "C",
      if (dPtr != null) "D",
    ];
    return "Blit ${channels.join()} ${width ?? 1} x ${height ?? 1}";
  }
}

/// A line blit.
class LineBlit extends BaseBlit {
  /// Line start coordinate.
  (int, int)? lineStart;

  /// Line end coordinate.
  (int, int)? lineEnd;

  /// Line texture.
  int lineTexture = 0xFFFF;

  /// Destination pointer.
  Label? dPtr;

  /// Destination stride in bytes.
  int? dStride;

  @override
  void addToCopper(Copper copper) {
    assert(
      lineStart != null && lineEnd != null,
      "Both lineStart and lineEnd must be specified",
    );
    assert(dPtr != null, "Destination pointer must be specified");
    assert(dStride != null, "Destination stride must be specified");

    var (startX, startY) = lineStart!;
    var (endX, endY) = lineEnd!;

    if (startY == endY) {
      return;
    } else if (startY > endY) {
      (startY, endY) = (endY, startY);
      (startX, endX) = (endX, startX);
    }

    var startWord = (startY * dStride! + startX ~/ 8) & ~1;

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

    copper.waitBlit();
    copper.move(BLTCMOD, dStride!);
    copper.move(BLTDMOD, dStride!);
    copper.move(BLTADAT, 0x8000);
    copper.move(BLTBDAT, lineTexture);
    copper.move(BLTAFWM, 0xFFFF);
    copper.move(BLTALWM, 0xFFFF);
    copper.move(BLTAPTL, bltaptl);
    copper.move(BLTCON0, bltcon0);
    copper.move(BLTCON1, bltcon1);
    copper.ptr(BLTCPT, dPtr! + startWord);
    copper.ptr(BLTDPT, dPtr! + startWord);
    copper.move(BLTBMOD, bltbmod);
    copper.move(BLTAMOD, bltamod);

    if (bltsizv < 1024) {
      copper.move(BLTSIZE, (bltsizv << 6) | 2);
    } else {
      copper.move(BLTSIZV, bltsizv);
      copper.move(BLTSIZH, 2);
    }
  }

  @override
  String toString() {
    var start = lineStart != null ? "(${lineStart!.$1},${lineStart!.$2})" : "";
    var end = lineEnd != null ? "(${lineEnd!.$1},${lineEnd!.$2})" : "";
    return "LineBlit $start -> $end";
  }
}

/// A copper component that simply waits for the blitter to finish.
class WaitBlit implements CopperComponent {
  @override
  void addToCopper(Copper copper) {
    copper.waitBlit();
  }

  @override
  String toString() => "WaitBlit";
}

/// A list of [Blit]s or [LineBlit]s that is itself a [CopperComponent].
class BlitList<B extends BaseBlit> extends DelegatingList<B>
    implements CopperComponent {
  BlitList(super.base);

  @override
  BlitList<B> sublist(int start, [int? end]) {
    return BlitList(super.sublist(start, end));
  }

  @override
  BlitList<B> operator +(List<B> other) {
    return BlitList(super + other);
  }

  @override
  void addToCopper(Copper copper) {
    // TODO: Omit redundant register writes.
    for (var blit in this) {
      blit.addToCopper(copper);
    }
  }

  @override
  String toString() => "BlitList $length";
}
