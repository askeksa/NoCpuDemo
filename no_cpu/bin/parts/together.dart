import 'package:no_cpu/no_cpu.dart';

import '../main.dart';
import '../effects/blitter_tornado.dart';

mixin Together on NoCpuDemoBase {
  static final Color sillhouetteColor = Color.rgb24(0x000000);
  static final Color flashColor = Color.rgb12(0xCCA);
  static final int flashDuration = 4;

  void together(int P) {
    var screen = Bitmap.space(320, 180, 8, interleaved: true);

    void sillhouette(int r, IlbmImage image, Bitmap mask, int offset) {
      var imageBitmap = image.bitmap.crop(h: 180);

      Blit push(Blit blit) {
        if (offset >= 0) {
          int words = offset >> 4;
          int shift = offset & 15;
          return blit
            ..cPtr = blit.cPtr! + words * 2
            ..dPtr = blit.dPtr! + words * 2
            ..aShift = shift
            ..bShift = shift
            ..width = blit.width! - words
            ..descending = false;
        } else {
          int words = -offset >> 4;
          int shift = -offset & 15;
          return blit
            ..aPtr = blit.aPtr! + words * 2
            ..bPtr = blit.bPtr! + words * 2
            ..aShift = shift
            ..bShift = shift
            ..width = blit.width! - words
            ..descending = true;
        }
      }

      Blit b(int p, int minterms) => push(
        Blit()
          ..aSetBitplane(mask, 0, w: 320, h: 180)
          ..bSetBitplane(imageBitmap, p, w: 320, h: 180)
          ..cdSetBitplane(screen, p, w: 320, h: 180)
          ..minterms = minterms,
      );

      F(P, 0, (-8 + r) * 6) - 3 |
          (i, f) {
            for (int j = 0; j < 2; j++) {
              int p = 7 - i * 2 - j;
              f << b(p, p == 7 ? C | A : A & B | ~A & C);
            }
          };

      F(P, 0, (-8 + r) * 6 + flashDuration) << b(7, C & ~A);
    }

    F(P, 0, -50) << (Blit()..dSetInterleaved(screen));

    var sillhouettePalette = Palette.generateRange(
      0,
      256,
      (i) => i == 0
          ? togetherColor
          : i < 128
          ? sillhouetteColor
          : flashColor,
    );
    F(P, 0, -8 * 6) >> sillhouettePalette;
    F(P, 0, -8 * 6) - (P, 0, -1) >> (Display()..setBitmap(screen));

    sillhouette(0, paula, paulaMask, -130);
    sillhouette(3, lisa, lisaMask, 180);
    sillhouette(6, alice, aliceMask, -70);

    var tornado = BlitterTornado();
    var spriteScreen = SpriteGroup.space(320, 180);
    var pal = lisa.palette | paula.palette.sub(97, 99);
    var tornadoPalette = spriteScreen.palette(
      Palette.generateRange(1, 3, (i) => pal[0] * (1.0 + i * 0.7)),
      240,
    );

    F(P, 0, -2) >> (Blit()..dSetInterleaved(tornado.bitmap1));
    F(P, 0, -1) >> (Blit()..dSetInterleaved(tornado.bitmap2));

    F(P, 0) << (pal | tornadoPalette);
    F(P, 0) << spriteScreen.updatePosition(v: 82);
    F(P, 0) << spriteScreen.updateTerminator();

    F(P, 0) - (P + 2, 0, -1) |
        (i, f) {
          f >>
              (Display()
                ..setBitmap(screen)
                ..sprites = spriteScreen.labels
                ..spriteColorOffset = 240
                ..priority = 0);
          var tornadoFrame = tornado.frame(i, -0.6, 1.03);
          for (int p = 0; p < 2; p++) {
            f >>
                spriteScreen.blit(
                  p,
                  aBitmap: tornadoFrame.back,
                  aFromPlane: p,
                  x: BlitterTornado.borderLeft,
                  y: BlitterTornado.borderTop,
                );
          }
          f << tornadoFrame;
        };
  }
}
