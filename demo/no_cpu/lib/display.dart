// Limitations so far:
// - Only lores
// - No special modes
// - No shifts
// - No sprites
// - No priorities
// - No color offsets

import 'copper.dart';
import 'custom.dart';
import 'memory.dart';

class Display implements CopperComponent {
  // Bitplane pointers.
  List<Label> bitplanes = [];

  // Distance in bytes from the beginning of one row to the next.
  int? oddStride, evenStride;

  // Bitplane alignment, corresponding to the fetch mode.
  int alignment = 3;

  set stride(int value) => oddStride = evenStride = value;

  int get depth => bitplanes.length;

  @override
  void addToCopper(Copper copper) {
    int bytesPerRow = 40;
    int oddStride = this.oddStride ?? bytesPerRow;
    int evenStride = this.evenStride ?? bytesPerRow;

    assert(depth <= 8);
    assert(alignment >= 1 && alignment <= 3);
    assert(oddStride.isAlignedTo(alignment));
    assert(evenStride.isAlignedTo(alignment));

    copper.move(DDFSTRT, 0x0038);
    copper.move(DDFSTOP, 0x00E0 - 0x10 * alignment);
    copper.move(BPLCON0, 0x0201 | (depth & 0x7) << 12 | (depth & 0x8) << 1);
    copper.move(BPLCON1, 0x0000);
    copper.move(BPLCON2, 0x0200);
    // BPLCON3 is written in palette.
    copper.move(BPLCON4, 0x0000);
    copper.move(BPL1MOD, oddStride - bytesPerRow);
    copper.move(BPL2MOD, evenStride - bytesPerRow);
    copper.move(FMODE, 0x000C | 0x3 >> (3 - alignment));
    for (int i = 0; i < depth; i++) {
      assert(bitplanes[i].isAlignedTo(alignment));
      copper.ptr(BPLxPT[i], bitplanes[i]);
    }
  }
}
