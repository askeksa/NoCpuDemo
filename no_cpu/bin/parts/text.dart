import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/transition.dart';
import '../effects/interference.dart';

mixin Text on NoCpuDemoBase {
  static final int flashDuration = 4;

  final ChunkyPixels noise = ChunkyPixels.fromFile(
    "$assetsPath/bluenoise3.raw",
    128,
    128,
  );

  Transition waveTrans = Transition.generate(320, 180, (x, y) {
    return 20 +
        x * (0.2 + y * 0.001) -
        y * 0.1 +
        (sin(y * 0.11 + x * 0.013) + sin(y * 0.13 - x * 0.015)) * 5;
  });

  late Transition checkerTrans = Transition.generate(320, 180, (x, y) {
    const size = 20;
    int cx = x - 160 - (x - 160 + size * 10) % size + size ~/ 2;
    int cy = y - 90 - (y - 90 + size * 10) % size + size ~/ 2;
    int d =
        ((cx * cx + cy * cy) ~/ 35 + noise.getPixel(x & 127, y & 127)) ~/ 20;
    bool xc = (cx + size * 10) % (size * 2) < size;
    bool yc = (cy + size * 10) % (size * 2) < size;
    return (xc ^ yc) ? d : d + 40;
  });

  final _interferencePaletteRebels = Interference.shuffleColorList([
    Color.rgb8(6, 7, 52),
    Color.rgb8(6, 15, 65),
    Color.rgb8(6, 27, 77),
    Color.rgb8(5, 44, 90),
    Color.rgb8(4, 63, 103),
    Color.rgb8(52, 78, 128),
    Color.rgb8(0, 113, 128),
    Color.rgb8(110, 64, 75),
    Color.rgb8(0, 155, 176),
    Color.rgb8(159, 70, 0),
    Color.rgb8(0, 213, 219),
    Color.rgb8(191, 67, 0),
    Color.rgb8(214, 200, 177),
    Color.rgb8(255, 72, 0),
    Color.rgb8(255, 142, 24),
    Color.rgb8(214, 99, 0),
  ]);

  List<Color> dimColors(List<Color> colors, double lightness) =>
      colors.map((c) => Color.black.interpolate(c, lightness)).toList();

  List<(int, int, SpriteGroup, Palette)> getWords(
    String filename,
    List<Object> splits,
  ) {
    IlbmImage image = IlbmImage.fromFile(filename);

    List<(int, int, SpriteGroup, Palette)> words = [];
    int lastSplit = 0;
    SpriteGroup? parent;

    void add(
      int x,
      int y,
      int width,
      int height,
      int baseIndex,
      bool sameParity,
    ) {
      int minc = 255, maxc = 0;
      var (cx, cy, cropped) = image.bitmap
          .crop(x: x, y: y, w: width, h: height)
          .transform((_, _, c) {
            if (c > 0) {
              minc = min(minc, c);
              maxc = max(maxc, c);
            }
            return c;
          })
          .transform((_, _, c) => c > 0 ? c - minc + 1 : 0)
          .autocrop();
      x += cx;
      y += cy;
      SpriteGroup sprite = SpriteGroup.fromBitmap(
        cropped,
        baseIndex: baseIndex,
        sameParity: sameParity,
        attached: maxc - minc > 2,
        parent: parent,
      );
      parent = sprite;
      var pal = sprite.palette(
        image.palette.sub(minc, maxc).shift(1 - minc),
        240,
      );
      words.add((x, y, sprite, pal));
    }

    for (var split in splits) {
      switch (split) {
        case int split:
          add(0, lastSplit, 320, split - lastSplit, 0, false);
          lastSplit = split;
          break;
        case (int split, int hsplit):
          add(0, lastSplit, hsplit, split - lastSplit, 0, true);
          add(hsplit, lastSplit, 320 - hsplit, split - lastSplit, 1, true);
          lastSplit = split;
          break;
      }
    }

    return words;
  }

  BlitList enableWord(List<(int, int, SpriteGroup, Palette)> words, int i) {
    var (x, y, sprite, pal) = words[i];
    return sprite.updatePosition(v: 82 + y, h: 0x200 + x * 4);
  }

  BlitList disableWord(List<(int, int, SpriteGroup, Palette)> words, int i) {
    var (x, y, sprite, pal) = words[i];
    return sprite.updatePosition(v: 0, h: 0);
  }

  CopperComponent setWordColors(List<(int, int, SpriteGroup, Palette)> words) {
    return AdHocCopperComponent((copper) {
      for (var (_, y, _, pal) in words) {
        copper.wait(v: 82 + y - 1);
        copper << pal;
      }
    });
  }

  void rebelsText(int P) {
    var words = getWords("$assetsPath/A GROUP OF REBELS TEXTIFF5.iff", [
      (40, 260),
      (70, 235),
      105,
      140,
      170,
    ]);

    var interference = Interference(1);
    var interferencePalette = interference.generatePaletteFromList(
      dimColors(_interferencePaletteRebels, 0.5),
    );

    Display interferenceDisplay(int frame) {
      return interference
          .frame(
            (sin(frame / 102 + 1.4) + sin(frame / 83 + 1)) / 2, // even X
            (sin(frame / 95 + 0.3) + sin(frame / 76 + 1.0)) / 2, // even Y
            (sin(frame / 115 + 3.2) + sin(frame / 89 + 1.5)) / 2, // odd X
            (sin(frame / 85 + 1.40) + sin(frame / 117 + 2.0)) / 2, // odd Y
            frame & 1 != 0, // flip
          )
          .display;
    }

    F(P, 2) << enableWord(words, 0);
    F(P, 6) << enableWord(words, 1);
    F(P, 8) << enableWord(words, 2);
    F(P, 12) << enableWord(words, 3);
    F(P, 14) << enableWord(words, 4);
    F(P, 16) << enableWord(words, 5);
    F(P, 20) << enableWord(words, 6);

    F(P, 30, 0) << disableWord(words, 6);
    F(P, 30, 2) << disableWord(words, 5);
    F(P, 30, 4) << disableWord(words, 4);
    F(P, 30, 6) << disableWord(words, 3);
    F(P, 30, 6) << disableWord(words, 2);
    F(P, 30, 8) << disableWord(words, 1);
    F(P, 30, 8) << disableWord(words, 0);

    F(P, 0) >> interferencePalette;
    F(P, 0) - (P, 32, -1) |
        (frame, copper) {
          copper <<
              (interferenceDisplay(frame)
                ..sprites = words[0].$3.labels
                ..spriteColorOffset = 240
                ..priority = 4);
        };
    F(P, 0) - (P, 32, -2) >> setWordColors(words);

    F(P, 32) >>
        spriteScreen.palette(Palette.fromMap({1: alice.palette[0]}), 240);
    F(P, 32) - (P + 1, 0, -64) |
        (frame, copper) {
          copper <<
              (interferenceDisplay(frame + 32 * 6)
                ..alignment = 2
                ..sprites = spriteScreen.labels
                ..spriteColorOffset = 240
                ..priority = 4);
        };

    transition(waveTrans, (P, 32), inverse: true);
  }

  void checkerboardText(int P) {
    var words = getWords("$assetsPath/NO CHALL CHECKERBOARDIFF3.iff", [
      40,
      77,
      110,
      150,
    ]);

    var interference = Interference(2);
    final interferencePalette = interference.generatePalette((i, maxIndex) {
      var colorF = i / (maxIndex + 1);
      return Color.rgb8(
        (sin(colorF * pi * 2 + pi / 3) * 20 + 74).toInt(),
        (sin(colorF * pi * 2 + 1.0) * 20 + 34).toInt(),
        (sin(colorF * pi * 2 + pi * 2 / 3 + 0.5) * 12 + 25).toInt(),
      );
    });

    Display interferenceDisplay(int frame) {
      return interference
          .frame(
            (sin(frame / 102 + 2.5) + sin(frame / 73 + 1.5)) / 2, // even X
            (sin(frame / 90 + 1.3) + sin(frame / 120 + 2)) / 2, // even Y
            (sin(frame / 75 + 0.5) + sin(frame / 90)) / 2, // odd X
            (sin(frame / 65 + 2.35) + sin(frame / 89 + 1)) / 2, // odd Y
            frame & 1 != 0, // flip
          )
          .display;
    }

    F(P, 16) << enableWord(words, 0);
    F(P, 18) << enableWord(words, 1);
    F(P, 22) << enableWord(words, 2);
    F(P, 28) << enableWord(words, 3);

    F(P, 44) << disableWord(words, 3);
    F(P, 44) << disableWord(words, 2);
    F(P, 44) << disableWord(words, 1);
    F(P, 44) << disableWord(words, 0);

    F(P, 0) >> interferencePalette;
    F(P, 0) - (P, 48, -1) |
        (frame, copper) {
          copper <<
              (interferenceDisplay(frame)
                ..sprites = words[0].$3.labels
                ..spriteColorOffset = 240
                ..priority = 4);
        };
    F(P, 0) - (P, 48, -2) >> setWordColors(words);

    F(P, 48) >>
        spriteScreen.palette(Palette.fromMap({1: Color.rgb12(0x000)}), 240);
    F(P, 48) - (P + 1, 0, -1) |
        (frame, copper) {
          copper <<
              (interferenceDisplay(frame + 48 * 6)
                ..alignment = 2
                ..sprites = spriteScreen.labels
                ..spriteColorOffset = 240
                ..priority = 4);
        };

    transition(checkerTrans, (P, 48), end: 16 * 6 - 1, inverse: true);
  }

  void joinText(int P) {
    var words = getWords("$assetsPath/JOIN THE REBELLIONIFF4.iff", [
      55,
      100,
      150,
    ]);

    var interference = Interference(3);
    final interferencePaletteJoin = interference.generatePaletteFromList(
      dimColors(
        Interference.shuffleColorList([
          Color.rgb8(101, 0, 0),
          Color.rgb8(136, 14, 0),
          Color.rgb8(110, 29, 0),
          Color.rgb8(145, 50, 0),
          Color.rgb8(183, 75, 0),
          Color.rgb8(52, 12, 0),
          Color.rgb8(255, 126, 0),
          Color.rgb8(46, 0, 0),
          Color.rgb8(255, 191, 0),
          Color.rgb8(75, 23, 0),
          Color.rgb8(255, 246, 130),
          Color.rgb8(110, 6, 0),
          Color.rgb8(255, 255, 241),
          Color.rgb8(165, 0, 0),
          Color.rgb8(237, 113, 0),
          Color.rgb8(255, 67, 0),
        ]),
        0.5,
      ),
    );

    Display interferenceDisplay(int frame) {
      return interference
          .frame(
            (sin(frame / 80 + 1.5) + sin(frame / 120)) / 2, // even X
            (sin(frame / 120 + 0.3) + sin(frame / 89)) / 2, // even Y
            (sin(frame / 50 + 3.2) + sin(frame / 130)) / 2, // odd X
            (sin(frame / 103 + 2.35) + sin(frame / 67)) / 2, // odd Y
            frame & 1 != 0, // flip
          )
          .display;
    }

    F(P, 8) << enableWord(words, 0);
    F(P, 12) << enableWord(words, 1);
    F(P, 16) << enableWord(words, 2);

    F(P, 26, 0) << disableWord(words, 2);
    F(P, 28, 0) << disableWord(words, 1);
    F(P, 30, 0) << disableWord(words, 0);

    F(P, 0, flashDuration) >> interferencePaletteJoin;
    F(P, 0, flashDuration) - (P, 32, -1) |
        (frame, copper) {
          copper <<
              (interferenceDisplay(flashDuration + frame)
                ..sprites = words[0].$3.labels
                ..spriteColorOffset = 240
                ..priority = 4);
        };
    F(P, 0, flashDuration) - (P, 32, -2) >> setWordColors(words);

    F(P, 32) >> spriteScreen.palette(Palette.fromMap({1: lifeColor}), 240);
    F(P, 32) - (P, 48, -1) |
        (frame, copper) {
          copper <<
              (interferenceDisplay(frame + 32 * 6)
                ..alignment = 2
                ..sprites = spriteScreen.labels
                ..spriteColorOffset = 240
                ..priority = 4);
        };

    transition(
      lifeTrans,
      (P, 32),
      end: 16 * 6 - 1,
      backward: true,
      inverse: false,
    );
  }
}
