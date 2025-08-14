import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/blitter_tornado.dart';
import '../effects/transition.dart';

mixin Together on NoCpuDemoBase {
  static final Color sillhouetteColor = Color.rgb24(0x000000);
  static final Color flashColor = Color.rgb12(0xCCA);
  static final int flashDuration = 4;

  static const titlePaletteOffset = 140;

  late final IlbmImage title = IlbmImage.fromFile(
    "$assetsPath/NO CPU CHALLENGE text4.iff",
  );

  final ChunkyPixels noise = ChunkyPixels.fromFile(
    "$assetsPath/bluenoise3.raw",
    128,
    128,
  );

  late final Bitmap titleBitmap = title.bitmap.crop(h: 80).autocrop().$3;
  late final Palette titlePalette = title.palette.sub(titlePaletteOffset);
  late final titleTrans = Transition.generate(
    titleBitmap.width,
    titleBitmap.height,
    (x, y) {
      if (titleBitmap.getPixel(x, y) == 0) return 0;
      x -= titleBitmap.width ~/ 2;
      return 128 - ((x * x ~/ 40) + noise.getPixel(x & 127, y)) ~/ 5;
    },
  );

  late final screen = Bitmap.space(320, 180, 8, interleaved: true);

  BlitList drawTitle(int x, int y) {
    return BlitList([
      for (int p = 0; p < 8; p++)
        Blit()
          ..aSetBitplane(titleTrans.result, 0)
          ..bSetBitplane(titleBitmap, p)
          ..abShift = x & 15
          ..cdSetBitplane(screen, p, x: x, y: y, size: false)
          ..width = (titleBitmap.bytesPerRow >> 1) + 1
          ..aLWM = 0
          ..minterms = A & B | ~A & C,
    ]);
  }

  void together(int P) {
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
    sillhouette(3, lisa, lisaMask, 183);
    sillhouette(6, alice, aliceMask, -70);

    var tornado = BlitterTornado();
    var spriteScreen = SpriteGroup.space(320, 180);
    var pal = lisa.palette | paula.palette.sub(97, 99);
    var tornadoPalette = spriteScreen.palette(
      Palette.generateRange(1, 3, (i) => pal[0] * (1.0 + (i + 1) * 0.5)),
      240,
    );

    F(P, 0, -2) >> (Blit()..dSetInterleaved(tornado.bitmap1));
    F(P, 0, -1) >> (Blit()..dSetInterleaved(tornado.bitmap2));

    F(P, 0) << (pal | titlePalette | tornadoPalette);
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

          var draw = drawTitle(36, 119);

          int threshold = i - 32 * 6;
          if (threshold >= 0 && threshold < 126) {
            if (i % 3 == 0) {
              f << titleTrans.run(127 - threshold);
            }
            if (i % 3 == 2) {
              f >> draw.sublist(4);
            }
          }

          f << tornadoFrame;

          if (threshold >= 0 && threshold < 126) {
            if (i % 3 == 1) {
              f >> draw.sublist(0, 4);
            }
          }
        };
  }
}
