// Limitations so far:
// - Only lores
// - No special modes
// - No bitplane color offsets

import 'dart:math';

import 'bitmap.dart';
import 'copper.dart';
import 'custom.dart';
import 'memory.dart';

class Display implements CopperComponent {
  // Bitplane pointers.
  List<Label> bitplanes = [];

  // Sprite pointers.
  List<Label?> sprites = [];

  // Distance in bytes from the beginning of one row to the next.
  int? oddStride, evenStride;

  // Playfield priorities relative to sprites.
  int oddPriority = 0, evenPriority = 0;

  // Sprite color offsets.
  int oddSpriteColorOffset = 0, evenSpriteColorOffset = 0;

  // Bitplane horizontal scroll in SHIRES pixels.
  int oddHorizontalScroll = 0, evenHorizontalScroll = 0;

  // Bitplane vertical scroll in rows.
  int oddVerticalScroll = 0, evenVerticalScroll = 0;

  // Whether the playfield is flipped vertically (negative modulo).
  bool oddFlip = false, evenFlip = false;

  // Bitplane alignment, corresponding to the fetch mode.
  int alignment = 3;

  set stride(int value) => oddStride = evenStride = value;
  set priority(int value) => oddPriority = evenPriority = value;
  set horizontalScroll(int value) =>
      oddHorizontalScroll = evenHorizontalScroll = value;
  set verticalScroll(int value) =>
      oddVerticalScroll = evenVerticalScroll = value;
  set spriteColorOffset(int value) =>
      oddSpriteColorOffset = evenSpriteColorOffset = value;
  set flip(bool value) => oddFlip = evenFlip = value;

  int get byteAlignment => 1 << alignment;
  int get depth => bitplanes.length;

  int get _pixelScrollMask => 0xFF >> (3 - alignment);
  bool get _hasPixelHScroll =>
      (evenHorizontalScroll & _pixelScrollMask != 0) ||
      (oddHorizontalScroll & _pixelScrollMask != 0);

  void setBitmap(Bitmap bitmap) {
    assert(bitmap.alignment >= alignment);
    assert(evenHorizontalScroll == oddHorizontalScroll);
    assert(evenVerticalScroll == oddVerticalScroll);
    bitplanes = List.generate(
      bitmap.depth,
      (i) =>
          bitmap.bitplanes +
          i * bitmap.planeStride +
          evenVerticalScroll * bitmap.rowStride +
          horizontalBitmapOffset(evenHorizontalScroll),
    );
    stride = bitmap.rowStride;
  }

  void setBitmaps(Bitmap evenBitmap, Bitmap oddBitmap) {
    assert(
      evenBitmap.alignment >= alignment && oddBitmap.alignment >= alignment,
    );
    bitplanes = List.generate(evenBitmap.depth + oddBitmap.depth, (i) {
      int plane = i >> 1;
      Bitmap bitmap = i & 1 == 0 ? evenBitmap : oddBitmap;
      int horizontalScroll = i & 1 == 0
          ? evenHorizontalScroll
          : oddHorizontalScroll;
      int verticalScroll = i & 1 == 0
          ? (evenFlip ? bitmap.height - evenVerticalScroll : evenVerticalScroll)
          : (oddFlip ? bitmap.height - oddVerticalScroll : oddVerticalScroll);
      return bitmap.bitplanes +
          plane * bitmap.planeStride +
          verticalScroll * bitmap.rowStride +
          horizontalBitmapOffset(horizontalScroll);
    });
    evenStride = evenBitmap.rowStride;
    oddStride = oddBitmap.rowStride;
  }

  int horizontalBitmapOffset(int horizontalScroll) {
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
    int oddStride = this.oddStride ?? bytesPerRow;
    int evenStride = this.evenStride ?? bytesPerRow;
    int moduloAdjust = _hasPixelHScroll ? byteAlignment : 0;

    int ddfStart = _hasPixelHScroll ? 0x0038 - (8 << alignment - 1) : 0x0038;
    int ddfStop = 0x00E0 - 0x10 * alignment;
    int maxSprites = min(8, (ddfStart - 0x14) >> 2);

    assert(depth <= 8);
    assert(sprites.length <= maxSprites);
    assert(alignment >= 1 && alignment <= 3);
    assert(oddStride.isAlignedTo(alignment));
    assert(evenStride.isAlignedTo(alignment));
    assert(oddPriority >= 0 && oddPriority <= 4);
    assert(evenPriority >= 0 && evenPriority <= 4);
    assert(oddSpriteColorOffset & ~0xF0 == 0);
    assert(evenSpriteColorOffset & ~0xF0 == 0);

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
                copper.move(BPLCON2, 0x0200 | evenPriority << 3 | oddPriority);
                // BPLCON3 is written in palette.
                copper.move(
                  BPLCON4,
                  evenSpriteColorOffset | oddSpriteColorOffset >> 4,
                );
                copper.move(
                  BPL1MOD,
                  evenStride -
                      bytesPerRow -
                      moduloAdjust -
                      (evenFlip ? evenStride * 2 : 0),
                );
                copper.move(
                  BPL2MOD,
                  oddStride -
                      bytesPerRow -
                      moduloAdjust -
                      (oddFlip ? oddStride * 2 : 0),
                );
                copper.move(FMODE, 0x000C | 0x3 >> (3 - alignment));

                copper >> SpritePointers(sprites);
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
    ).label;
    for (int i = 0; i < 8; i++) {
      copper.ptr(
        SPRxPT[i],
        i < sprites.length ? sprites[i] ?? emptySprite : emptySprite,
      );
    }
  }
}
