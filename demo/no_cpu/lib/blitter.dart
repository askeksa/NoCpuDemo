import 'copper.dart';
import 'custom.dart';
import 'memory.dart';

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

class Blit implements CopperComponent {
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

  /// Width (in words) and height (in rows) of the blit operation.
  int width = 1, height = 1;

  /// Shorthands for setting multiple pointers.
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

  /// Shorthands for setting multiple strides.
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

  /// Shorthands for setting multiple data values.
  set abData(int value) => aData = bData = value;
  set acData(int value) => aData = cData = value;
  set bcData(int value) => bData = cData = value;
  set abcData(int value) => aData = bData = cData = value;

  /// Shorthand for setting multiple shift values.
  set abShift(int value) => aShift = bShift = value;

  @override
  void addToCopper(Copper copper) {
    int channelMask =
        this.channelMask ??
        (aPtr != null ? 0x8 : 0) |
            (bPtr != null ? 0x4 : 0) |
            (cPtr != null ? 0x2 : 0) |
            (dPtr != null ? 0x1 : 0);
    bool aEnabled = channelMask & 0x8 != 0;
    bool bEnabled = channelMask & 0x4 != 0;
    bool cEnabled = channelMask & 0x2 != 0;
    bool dEnabled = channelMask & 0x1 != 0;

    bool aInput = aEnabled || aData != null;
    bool bInput = bEnabled || bData != null;
    bool cInput = cEnabled || cData != null;
    int minterms =
        this.minterms ?? (aInput ? A : 0) ^ (bInput ? B : 0) ^ (cInput ? C : 0);

    int ptrOffset = descending ? width * 2 - 2 : 0;
    int stride2modulo(int? stride) {
      stride ??= width * 2;
      return (descending ? -stride : stride) - width * 2;
    }

    int bltcon0 = (aShift << 12) | (channelMask << 8) | minterms;
    int bltcon1 = (bShift << 12) | (descending ? 0x0002 : 0);

    copper.waitBlit();
    copper.move(BLTCON0, bltcon0);
    copper.move(BLTCON1, bltcon1);
    copper.move(BLTAFWM, aFWM);
    copper.move(BLTALWM, aLWM);
    if (cPtr != null) copper.ptr(BLTCPT, cPtr! + ptrOffset);
    if (bPtr != null) copper.ptr(BLTBPT, bPtr! + ptrOffset);
    if (aPtr != null) copper.ptr(BLTAPT, aPtr! + ptrOffset);
    if (dPtr != null) copper.ptr(BLTDPT, dPtr! + ptrOffset);
    if (cEnabled) copper.move(BLTCMOD, stride2modulo(cStride));
    if (bEnabled) copper.move(BLTBMOD, stride2modulo(bStride));
    if (aEnabled) copper.move(BLTAMOD, stride2modulo(aStride));
    if (dEnabled) copper.move(BLTDMOD, stride2modulo(dStride));
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
  }
}

/// A copper component that simply waits for the blitter to finish.
class WaitBlit implements CopperComponent {
  @override
  void addToCopper(Copper copper) {
    copper.waitBlit();
  }
}
