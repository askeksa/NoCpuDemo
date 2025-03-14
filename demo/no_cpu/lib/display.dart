// Limitations so far:
// - Only lores
// - No special modes
// - No shifts
// - No bitplane color offsets

import 'bitmap.dart';
import 'copper.dart';
import 'custom.dart';
import 'memory.dart';

class Display implements CopperComponent {
  // Bitplane pointers.
  List<Label> bitplanes = [];

  // Sprite pointers.
  List<Label> sprites = [];

  // Distance in bytes from the beginning of one row to the next.
  int? oddStride, evenStride;

  // Playfield priorities relative to sprites.
  int oddPriority = 0, evenPriority = 0;

  // Sprite color offsets.
  int oddSpriteColorOffset = 0, evenSpriteColorOffset = 0;

  // Bitplane alignment, corresponding to the fetch mode.
  int alignment = 3;

  set stride(int value) => oddStride = evenStride = value;
  set priority(int value) => oddPriority = evenPriority = value;
  set spriteColorOffset(int value) =>
      oddSpriteColorOffset = evenSpriteColorOffset = value;

  int get depth => bitplanes.length;

  void setBitmap(Bitmap bitmap) {
    assert(bitmap.alignment >= alignment);
    bitplanes = List.generate(
      bitmap.depth,
      (i) => bitmap.bitplanes + i * bitmap.planeStride,
    );
    stride = bitmap.rowStride;
  }

  @override
  void addToCopper(Copper copper) {
    int bytesPerRow = 40;
    int oddStride = this.oddStride ?? bytesPerRow;
    int evenStride = this.evenStride ?? bytesPerRow;

    assert(depth <= 8);
    assert(sprites.length <= 8);
    assert(alignment >= 1 && alignment <= 3);
    assert(oddStride.isAlignedTo(alignment));
    assert(evenStride.isAlignedTo(alignment));
    assert(oddPriority >= 0 && oddPriority <= 4);
    assert(evenPriority >= 0 && evenPriority <= 4);
    assert(oddSpriteColorOffset & ~0xF0 == 0);
    assert(evenSpriteColorOffset & ~0xF0 == 0);

    copper.move(DDFSTRT, 0x0038);
    copper.move(DDFSTOP, 0x00E0 - 0x10 * alignment);
    copper.move(BPLCON0, 0x0201 | (depth & 0x7) << 12 | (depth & 0x8) << 1);
    copper.move(BPLCON1, 0x0000);
    copper.move(BPLCON2, 0x0200 | evenPriority << 3 | oddPriority);
    // BPLCON3 is written in palette.
    copper.move(BPLCON4, evenSpriteColorOffset | oddSpriteColorOffset >> 4);
    copper.move(BPL1MOD, oddStride - bytesPerRow);
    copper.move(BPL2MOD, evenStride - bytesPerRow);
    copper.move(FMODE, 0x000C | 0x3 >> (3 - alignment));
    for (int i = 0; i < depth; i++) {
      assert(bitplanes[i].isAlignedTo(alignment));
      copper.ptr(BPLxPT[i], bitplanes[i]);
    }

    copper >> SpritePointers(sprites);
  }
}

class SpritePointers implements CopperComponent {
  List<Label> sprites;

  SpritePointers(this.sprites);

  @override
  void addToCopper(Copper copper) {
    late Label empty = (Data()..addSpace(16)).label;
    for (int i = 0; i < 8; i++) {
      copper.ptr(SPRxPT[i], i < sprites.length ? sprites[i] : empty);
    }
  }
}
