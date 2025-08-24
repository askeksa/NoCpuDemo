// Limitations so far:
// - Only lores
// - No special modes
// - No bitplane color offsets

import 'dart:math';

import 'bitmap.dart';
import 'copper.dart';
import 'custom.dart';
import 'memory.dart';

/// Set display of playfields and sprites.
///
/// NOTE: The AHRM counts bitplanes from 1, but this abstraction deviates from
/// that convention and counts bitplanes from 0, like sprites, colors and audio
/// channels. This means that all mentions off "odd" and "even" as they pertain
/// to bitplanes or playfields are reversed relative to the AHRM.
class Display implements CopperComponent {
  /// Bitplane pointers.
  ///
  /// The length of the list determines the depth of the display.
  List<Label> bitplanes = [];

  /// Sprite pointers.
  ///
  /// Indices that are `null`, or beyond the end of the list, are set to an
  /// empty sprite.
  ///
  /// If the field is `null`, no sprite pointers are set.
  List<Label?>? sprites = [];

  /// Distance in bytes from the beginning of one row to the next.
  ///
  /// Default to the natural width of the display (i.e. 40 bytes for lores).
  int? evenStride, oddStride;

  /// Playfield priorities relative to sprites.
  int evenPriority = 0, oddPriority = 0;

  /// Sprite color offsets.
  int evenSpriteColorOffset = 0, oddSpriteColorOffset = 0;

  /// Bitplane horizontal scroll in SHIRES pixels.
  ///
  /// The values are positive to the left (opposite of the scroll register
  /// direction), and the values can be arbitrarily big. Bitplane pointers and
  /// data fetch are adjusted accordingly.
  int evenHorizontalScroll = 0, oddHorizontalScroll = 0;

  /// Bitplane vertical scroll in rows.
  ///
  /// The values are positive up. Bitplane pointers are adjusted accordingly.
  int evenVerticalScroll = 0, oddVerticalScroll = 0;

  /// Bitplane alignment, corresponding to the fetch mode.
  int alignment = 3;

  set stride(int value) => evenStride = oddStride = value;
  set priority(int value) => evenPriority = oddPriority = value;
  set horizontalScroll(int value) =>
      evenHorizontalScroll = oddHorizontalScroll = value;
  set verticalScroll(int value) =>
      evenVerticalScroll = oddVerticalScroll = value;
  set spriteColorOffset(int value) =>
      evenSpriteColorOffset = oddSpriteColorOffset = value;

  int get byteAlignment => 1 << alignment;
  int get depth => bitplanes.length;

  int get _pixelScrollMask => 0xFF >> (3 - alignment);
  bool get _hasPixelHScroll =>
      (evenHorizontalScroll & _pixelScrollMask != 0) ||
      (oddHorizontalScroll & _pixelScrollMask != 0);

  /// Set bitplane pointers and strides from a bitmap.
  ///
  /// If [flip] is true, the bitmap is flipped vertically.
  void setBitmap(Bitmap bitmap, {bool flip = false}) {
    assert(bitmap.alignment >= alignment);
    assert(evenHorizontalScroll == oddHorizontalScroll);
    assert(evenVerticalScroll == oddVerticalScroll);
    bitplanes = List.generate(
      bitmap.depth,
      (i) =>
          bitmap.bitplanes +
          i * bitmap.planeStride +
          (flip ? (bitmap.height - 1) * bitmap.rowStride : 0),
    );

    assert(evenStride == null && oddStride == null);
    stride = flip ? -bitmap.rowStride : bitmap.rowStride;
  }

  /// Set bitplane pointers and strides from two independent bitmaps, one for
  /// each playfield.
  ///
  /// If [evenFlip] is true, the even bitmap is flipped vertically.
  /// If [oddFlip] is true, the odd bitmap is flipped vertically.
  void setBitmaps(
    Bitmap evenBitmap,
    Bitmap oddBitmap, {
    bool evenFlip = false,
    bool oddFlip = false,
  }) {
    assert(evenBitmap.alignment >= alignment);
    assert(oddBitmap.alignment >= alignment);
    bitplanes = List.generate(evenBitmap.depth + oddBitmap.depth, (i) {
      int plane = i >> 1;
      Bitmap bitmap = i & 1 == 0 ? evenBitmap : oddBitmap;
      bool flip = i & 1 == 0 ? evenFlip : oddFlip;
      return bitmap.bitplanes +
          plane * bitmap.planeStride +
          (flip ? (bitmap.height - 1) * bitmap.rowStride : 0);
    });

    assert(evenStride == null && oddStride == null);
    evenStride = evenFlip ? -evenBitmap.rowStride : evenBitmap.rowStride;
    oddStride = oddFlip ? -oddBitmap.rowStride : oddBitmap.rowStride;
  }

  int _horizontalBitmapOffset(int horizontalScroll) {
    int pixelScroll = horizontalScroll & _pixelScrollMask;
    int wordScroll =
        (horizontalScroll & ~_pixelScrollMask) >> 6; // 64 shres pixels per word

    if (_hasPixelHScroll && pixelScroll == 0) {
      // If we're pixel scrolling (DDFSTRT outside border), but this playfield
      // is not pixelscrolling, then correct bitmap pointer
      return wordScroll * 2 - byteAlignment;
    }

    return wordScroll * 2;
  }

  @override
  void addToCopper(Copper copper) {
    int bytesPerRow = 40;
    int evenStride = this.evenStride ?? bytesPerRow;
    int oddStride = this.oddStride ?? bytesPerRow;

    var bitplanes = List.generate(this.bitplanes.length, (i) {
      bool even = i & 1 == 0;
      var bitplane = this.bitplanes[i];

      int horizontalScroll = even ? evenHorizontalScroll : oddHorizontalScroll;
      int verticalScroll = even ? evenVerticalScroll : oddVerticalScroll;
      int stride = even ? evenStride : oddStride;
      return bitplane +
          verticalScroll * stride +
          _horizontalBitmapOffset(horizontalScroll);
    });

    int moduloAdjust = _hasPixelHScroll ? byteAlignment : 0;

    int ddfStart = _hasPixelHScroll ? 0x0038 - (8 << alignment - 1) : 0x0038;
    int ddfStop = 0x00E0 - 0x10 * alignment;
    int maxSprites = min(8, (ddfStart - 0x14) >> 2);

    assert(depth <= 8);
    assert(sprites == null || sprites!.length <= maxSprites);
    assert(alignment >= 1 && alignment <= 3);
    assert(evenStride.isAlignedTo(alignment));
    assert(oddStride.isAlignedTo(alignment));
    assert(evenPriority >= 0 && evenPriority <= 4);
    assert(oddPriority >= 0 && oddPriority <= 4);
    assert(evenSpriteColorOffset & ~0xF0 == 0);
    assert(oddSpriteColorOffset & ~0xF0 == 0);

    copper.move(
      BPLCON1,
      _swizzleHorizontalScroll(evenHorizontalScroll) |
          (_swizzleHorizontalScroll(oddHorizontalScroll) << 4),
    );

    copper ^
        (copper) {
          for (int i = 0; i < depth; i++) {
            assert(bitplanes[i].isAlignedTo(alignment));
            copper.ptr(BPLxPT[i], bitplanes[i]);
          }
          copper ^
              (copper) {
                copper.move(DDFSTRT, ddfStart);
                copper.move(DDFSTOP, ddfStop);
                copper.move(
                  BPLCON0,
                  0x0201 | (depth & 0x7) << 12 | (depth & 0x8) << 1,
                );
                copper.move(BPLCON2, 0x0200 | oddPriority << 3 | evenPriority);
                // BPLCON3 is written in palette.
                copper.move(
                  BPLCON4,
                  evenSpriteColorOffset | oddSpriteColorOffset >> 4,
                );
                copper.move(BPL1MOD, evenStride - bytesPerRow - moduloAdjust);
                copper.move(BPL2MOD, oddStride - bytesPerRow - moduloAdjust);
                copper.move(FMODE, 0x000C | 0x3 >> (3 - alignment));

                if (sprites != null) {
                  copper >> SpritePointers(sprites!);
                }
              };
        };
  }

  int _swizzleHorizontalScroll(int scroll) {
    scroll &= _pixelScrollMask;
    scroll = 1 + _pixelScrollMask - scroll;

    return ((scroll & 0xC0) << 4) |
        ((scroll & 0x3C) >> 2) |
        ((scroll & 0x03) << 8);
  }

  @override
  String toString() => "Display ${bitplanes.length} ${sprites?.length ?? "-"}";
}

class SpritePointers implements CopperComponent {
  List<Label?> sprites;

  SpritePointers(this.sprites);

  @override
  void addToCopper(Copper copper) {
    late Label emptySprite = Data.blank(
      16,
      alignment: 3,
      mutability: Mutability.immutable,
      origin: "Empty sprite",
    ).label;
    for (int i = 0; i < 8; i++) {
      copper.ptr(
        SPRxPT[i],
        i < sprites.length ? sprites[i] ?? emptySprite : emptySprite,
      );
    }
  }

  @override
  String toString() => "SpritePointers ${sprites.length}";
}
