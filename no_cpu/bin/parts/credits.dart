import 'dart:math';

import 'package:collection/collection.dart';
import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';

mixin Credits on NoCpuDemoBase {
  static final Color flashColor = Color.rgb12(0xCCA);
  static final int flashDuration = 4;

  void credits(int P) {
    void girl(int p, IlbmImage image, Bitmap mask, int dir) {
      F(p, 0, 0) - (flashDuration - 1) << blankDisplay(flashColor);
      F(p, 0, flashDuration) - (10 - flashDuration - 1) <<
          blankDisplay(image.palette[0]);

      var imageBitmap = image.bitmap.crop(h: 180);
      var padded = Bitmap.space(960, 180, 8, interleaved: true);
      F(p, 0, 0) << (Blit()..dSetInterleaved(padded, x: 0, w: 320));
      F(p, 0, 1) << (Blit()..dSetInterleaved(padded, x: 640, w: 320));
      for (int i = 0; i < 8; i++) {
        F(p, 0, 2 + i) <<
            (Blit()
              ..aSetBitplane(mask, 0, w: 320, h: 180)
              ..bSetBitplane(imageBitmap, i, w: 320, h: 180)
              ..dSetBitplane(padded, i, x: 320, w: 320, h: 180)
              ..minterms = A & B);
      }

      F(p, 0, 10) << image.palette;
      F(p, 0, 10) - (p + 1, 0, -1) ^
          (i, c) {
            int t = max(0, max(8 * 6 - 10 - i, i - 56 * 6 - 10));
            int x = min(t * t + t, 320 * 4);
            c >>
                (Display()
                  ..horizontalScroll = 320 * 4 + x * dir
                  ..setBitmap(padded));
          };
    }

    girl(P, alice, aliceMask, -1);
    girl(P + 1, lisa, lisaMask, 1);
    girl(P + 2, paula, paulaMask, -1);

    F(P + 3, 0, 0) - (flashDuration - 1) << blankDisplay(flashColor);
    F(P + 3, 0, flashDuration) - (P + 4, 0, -1) <<
        blankDisplay(Color.rgb12(0x000));
  }
}
