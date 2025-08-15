import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/kaleidoscope_32.dart';
import '../effects/transition.dart';

mixin Credits on NoCpuDemoBase {
  static final Color flashColor = Color.rgb12(0xCCA);
  static final int flashDuration = 4;
  static final int kaleidoscopeFrameskip = 2;

  late final Kaleidoscope kaleidoscope = Kaleidoscope();

  static final IlbmImage codeImage = IlbmImage.fromFile(
    "$assetsPath/Credits code by.iff",
  );
  static final IlbmImage graphicsImage = IlbmImage.fromFile(
    "$assetsPath/Credits graphics by.iff",
  );
  static final IlbmImage musicImage = IlbmImage.fromFile(
    "$assetsPath/Credits music by.iff",
  );

  final ChunkyPixels noise = ChunkyPixels.fromFile(
    "$assetsPath/bluenoise3.raw",
    128,
    128,
  );

  late final Transition fadeTrans = Transition.generate(
    64,
    20,
    (x, y) => noise.getPixel(x, y) * 128 ~/ 255,
  );

  late final Bitmap fadeMask = Bitmap.space(
    fadeTrans.result.width,
    fadeTrans.result.height,
    8,
    interleaved: true,
  );

  static List<(int, int, Bitmap)> getWords(
    IlbmImage wordsImage,
    List<(int, int)> colors,
  ) {
    List<(int, int, Bitmap)> wordBitmaps = [];
    for (int i = 0; i < colors.length; i++) {
      var (base, count) = colors[i];
      var word = wordsImage.bitmap
          .transform((_, _, p) => p >= base && p < base + count ? p : 0)
          .autocrop();
      wordBitmaps.add(word);
    }
    return wordBitmaps;
  }

  void credits(int P) {
    void girl(
      int p,
      Kaleidoscope kaleidoscope,
      IlbmImage image,
      Bitmap mask,
      int dir,
      IlbmImage wordsImage,
      List<(int, int)> wordColors,
      (int, int?)? Function(int, int) placeWord,
    ) {
      var words = getWords(wordsImage, wordColors);

      F(p, 0, 0) - (flashDuration - 1) << blankDisplay(flashColor);

      var imageBitmap = image.bitmap.crop(h: 180);
      var padded = Bitmap.space(960, 180, 8, interleaved: true);
      F(p, 0, 0) << (Blit()..dSetInterleaved(padded, x: 0, w: 320));
      F(p, 0, 1) << (Blit()..dSetInterleaved(padded, x: 640, w: 320));
      for (int i = 0; i < 8; i++) {
        F(p, 0, 2 + (i >> 2)) <<
            (Blit()
              ..aSetBitplane(mask, 0, w: 320, h: 180)
              ..bSetBitplane(imageBitmap, i, w: 320, h: 180)
              ..dSetBitplane(padded, i, x: 320, w: 320, h: 180)
              ..minterms = A & B);
      }

      Blit blitWord(int i, (int, int?) where) {
        var (x, y, bitmap) = words[i];
        var (xOffset, fade) = where;
        x += 320 + xOffset;
        var draw = Blit()
          ..aSetInterleaved(bitmap)
          ..width = bitmap.bytesPerRow ~/ 2 + 1
          ..aLWM = 0
          ..cdSetInterleaved(padded, x: x, y: y, size: false)
          ..aShift = x & 15;

        if (fade != null) {
          return draw
            ..bSetInterleaved(fadeMask, size: false)
            ..bShift = x & 15
            ..minterms = (A & B) ^ C;
        } else {
          return draw..minterms = A ^ C;
        }
      }

      int scroll(int i) {
        int t = max(0, max(8 * 6 - i, i - 56 * 6));
        return min(t * t + t, 320 * 4);
      }

      (int, int?)? place(int i, int w) {
        if (w == 0) return (scroll(i) ~/ 2 * dir, null);
        return placeWord(i, w);
      }

      var pal = wordsImage.palette;
      var bgPalette = Palette.generateRange(
        241,
        15,
        (i) => pal[0] * (1.0 + ((i + 1) & 3) * 0.5),
      );

      F(p, 0, flashDuration) << (pal | bgPalette);
      F(p, 0, flashDuration) - (p + 1, 0, -1) |
          (i, f) {
            i += flashDuration;
            int s = scroll(i);
            f >>
                (Display()
                  ..horizontalScroll = 320 * 4 + s * dir
                  ..setBitmap(padded)
                  ..alignment = 2
                  ..sprites = kaleidoscope.displayForFrame(i).sprites
                  ..spriteColorOffset = 240
                  ..priority = 0);

            var prev = [for (int w = 0; w < words.length; w++) place(i - 1, w)];
            var curr = [for (int w = 0; w < words.length; w++) place(i, w)];
            var next = [for (int w = 0; w < words.length; w++) place(i + 1, w)];

            int? fade = curr
                .map((c) => c?.$2)
                .singleWhere((c) => c != null, orElse: () => null);

            if (fade != null) {
              f << fadeTrans.run(fade, inverse: true);
              f ^
                  (copper) {
                    for (int p = 0; p < 8; p++) {
                      copper <<
                          (Blit()
                            ..aSetBitplane(fadeTrans.result, 0)
                            ..dSetBitplane(fadeMask, p));
                    }
                  };
            }

            for (int w = 0; w < words.length; w++) {
              if (curr[w] != null && curr[w] != prev[w]) {
                f >> blitWord(w, curr[w]!);
              }
            }

            f >> kaleidoscope.footer(i);

            f.wait(v: 82 + 32);
            f << kaleidoscope.frame(i + 1);

            f.wait(v: 222);
            for (int w = 0; w < words.length; w++) {
              if (curr[w] != null && curr[w] != next[w]) {
                f >> blitWord(w, curr[w]!);
              }
            }
          };
    }

    var codeWords = [(95, 2), (89, 2), (101, 2), (97, 4), (93, 2)];
    var graphicsWords = [(90, 2), (96, 6), (88, 2)];
    var musicWords = [(59, 2), (67, 6), (57, 2), (61, 2)];

    (int, int?)? fadeInOut(int i, int a, int b) {
      int f = min(i - a * 6, b * 6 - i) * 4;
      return f < 0
          ? null
          : f <= 128
          ? (0, f)
          : (0, null);
    }

    (int, int?)? codePlace(int i, int w) {
      int r = i ~/ 6;
      switch (w) {
        case 1:
          return fadeInOut(i, 8, 40);
        case 2:
          return r >= 16 && r < 48 ? (0, null) : null;
        case 3:
          return fadeInOut(i, 16, 54);
        case 4:
          return r >= 24 && r < 52 ? (0, null) : null;
      }
      return null;
    }

    (int, int?)? graphicsPlace(int i, int w) {
      int r = i ~/ 6;
      switch (w) {
        case 1:
          return fadeInOut(i, 8, 54);
        case 2:
          return r >= 16 && r < 48 ? (0, null) : null;
      }
      return null;
    }

    (int, int?)? musicPlace(int i, int w) {
      int r = i ~/ 6;
      switch (w) {
        case 1:
          return fadeInOut(i, 8, 54);
        case 2:
          return r >= 16 && r < 48 ? (0, null) : null;
        case 3:
          return r >= 24 && r < 52 ? (0, null) : null;
      }
      return null;
    }

    F(P, 0, -3) - 1 | (i, f) => f << kaleidoscope.init(i);

    var codeKaleidoscope = kaleidoscope
      ..pattern1 = 1
      ..reversePattern1 = true
      ..pattern2 = 0
      ..reversePattern2 = true;

    F(P, 0, -1) << codeKaleidoscope.frame(flashDuration);
    girl(
      P,
      codeKaleidoscope,
      alice,
      aliceMask,
      -1,
      codeImage,
      codeWords,
      codePlace,
    );

    kaleidoscope.pattern1 = 0;
    kaleidoscope.reversePattern1 = false;
    kaleidoscope.pattern2 = 2;
    kaleidoscope.reversePattern2 = false;

    F(P + 1, 0, -1) << kaleidoscope.frame(flashDuration);
    girl(
      P + 1,
      kaleidoscope,
      lisa,
      lisaMask,
      1,
      graphicsImage,
      graphicsWords,
      graphicsPlace,
    );

    kaleidoscope.pattern1 = 2;
    kaleidoscope.reversePattern1 = true;
    kaleidoscope.pattern2 = 1;
    kaleidoscope.reversePattern2 = false;

    F(P + 2, 0, -1) << kaleidoscope.frame(flashDuration);
    girl(
      P + 2,
      kaleidoscope,
      paula,
      paulaMask,
      -1,
      musicImage,
      musicWords,
      musicPlace,
    );

    F(P + 3, 0, 0) - (flashDuration - 1) << blankDisplay(flashColor);
  }
}
