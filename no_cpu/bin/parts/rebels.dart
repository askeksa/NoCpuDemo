import 'dart:math';

import 'package:collection/collection.dart';
import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/transition.dart';

mixin Rebels on NoCpuDemoBase {
  late IlbmImage alice = IlbmImage.fromFile(
    "$assetsPath/!ALICE CYCLE Done4.iff",
  );
  late IlbmImage lisa = IlbmImage.fromFile("$assetsPath/!LISA CYCLE done2.iff");
  late IlbmImage paula = IlbmImage.fromFile(
    "$assetsPath/!PAULA CYCLE DONE.iff",
  );

  late IlbmImage aliceWordImage = IlbmImage.fromFile(
    "$assetsPath/!ALICE WORDCLOUD_Done.iff",
  );
  late IlbmImage lisaWordImage = IlbmImage.fromFile(
    "$assetsPath/!LISA WORDCLOUDS Done.iff",
  );
  late IlbmImage paulaWordImage = IlbmImage.fromFile(
    "$assetsPath/!PAULA WORDCLOUD DONE2.iff",
  );

  late List<(int, int, SpriteGroup, Palette)> aliceWords = getWords(
    aliceWordImage,
    89,
    5,
  );
  late List<(int, int, SpriteGroup, Palette)> lisaWords = getWords(
    lisaWordImage,
    88,
    5,
  );
  late List<(int, int, SpriteGroup, Palette)> paulaWords = getWords(
    paulaWordImage,
    57,
    5,
  );

  late Color aliceBg = alice.palette[0];
  late Color lisaBg = lisa.palette[0];
  late Color paulaBg = paula.palette[0];
  late Color finalBg = Color.rgb24(0x000000);

  SpriteGroup spriteScreen = SpriteGroup.space(320, 180);
  Palette spritePal(Color color) =>
      spriteScreen.palette(Palette.fromMap({1: color}), 240);

  static List<(int, int, SpriteGroup, Palette)> getWords(
    IlbmImage wordsImage,
    int baseColor,
    int count,
  ) {
    List<(int, int, Bitmap, Palette)> wordBitmaps = [];
    for (int i = 0; i < count; i++) {
      int color = baseColor + i * 2;
      var (x, y, word) = wordsImage.bitmap
          .transform(
            (x, y, p) => p >= color && p <= color + 1 ? p - color + 1 : 0,
          )
          .autocrop();
      wordBitmaps.add((
        x,
        y,
        word,
        wordsImage.palette.sub(color, color + 1).shift(-color + 1),
      ));
    }

    wordBitmaps.sortBy((w) => w.$2);

    List<SpriteGroup?> parents = [null, null];
    List<(int, int, SpriteGroup, Palette)> words = [];
    for (int i = 0; i < count; i++) {
      var (x, y, bitmap, pal) = wordBitmaps[i];
      int parity = i & 1;
      var sprite = SpriteGroup.fromBitmap(
        bitmap,
        baseIndex: parity,
        sameParity: true,
        parent: parents[parity],
      );
      parents[parity] = sprite;
      words.add((x, y, sprite, sprite.palette(pal, 224, 240)));
    }

    return words;
  }

  List<Label?> wordsLabels(List<(int, int, SpriteGroup, Palette)> words) {
    List<Label?> labels = List.filled(8, null);
    for (int w = 0; w < 2; w++) {
      for (var (i, label) in words[w].$3.labels.indexed) {
        if (label != null) labels[i] = label;
      }
    }
    return labels;
  }

  void displayWords(
    Copper copper,
    List<(int, int, SpriteGroup, Palette)> words,
    List<(int?, int)> offsets,
  ) {
    for (var (i, word) in words.indexed) {
      var (ox, oy) = offsets[i];
      copper <<
          word.$3.updatePosition(
            v: 82 + word.$2 + oy,
            h: ox != null ? 0x200 + (word.$1 + ox) * 4 : 0x700,
          );
    }
    for (var word in words) {
      copper.wait(v: 82 + word.$2 - 1);
      copper << word.$4;
    }
  }

  void rebels(int P) {
    Transition trans = Transition.generate(320, 180, (x, y) {
      return 20 +
          x * (0.2 + y * 0.001) -
          y * 0.1 +
          (sin(y * 0.11 + x * 0.013) + sin(y * 0.13 - x * 0.015)) * 5;
    });

    void girl(
      int p,
      IlbmImage image,
      List<(int, int, SpriteGroup, Palette)> words,
      Color bg,
      int dir,
      bool reverse,
      int rate,
      List<(int?, int)> Function(int) offsets,
    ) {
      // Slide girl in
      var padded = Bitmap.space(960, 180, 8, interleaved: true);
      F(p, 0, -64) << (Blit()..dSetInterleaved(padded));
      F(p, 0, -61) <<
          (Blit()
            ..aSetInterleaved(image.bitmap, w: 320, h: 180)
            ..dSetInterleaved(padded, x: 320, w: 320, h: 180));

      var pal = image.palette;
      for (var range in image.colorRanges) {
        pal =
            pal |
            Palette.fromList(
              start: range.low,
              List.filled(range.high - range.low + 1, image.palette[0]),
            );
      }

      F(p, 0, -60) >> pal;
      F(p, 0, -60) - (p, 0, -1) ^
          (i, c) {
            int t = max(0, 48 - i);
            int x = min(t * t + t, 320 * 4);
            c <<
                (Display()
                  ..horizontalScroll = 320 * 4 + x * dir
                  ..setBitmap(padded));
          };

      // Color cycling
      for (var range in image.colorRanges) {
        F(p, 0) - (p + 2, 0, -61) ^
            (i, f) {
              if (i % rate == 0) {
                int n = i ~/ rate;
                var pal = range.step(n);
                if (n < range.high - range.low + 1) {
                  pal = Palette.generateRange(
                    range.low,
                    n,
                    (c) => pal[range.low + c],
                  );
                }
                f >> pal;
              }
            };
      }

      // Word cloud
      F(p, 0) - (p + 1, 32, -2) >>
              (Display()
                ..setBitmap(image.bitmap)
                ..sprites = wordsLabels(words)
                ..evenSpriteColorOffset = 224
                ..oddSpriteColorOffset = 240
                ..priority = 4) ^
          (i, f) => displayWords(f, words, offsets(i));
      F(p + 1, 32, -1) >> (Display()..setBitmap(image.bitmap));

      // Wipe
      F(p + 1, 32) >> spritePal(bg);
      F(p + 1, 32) >> spriteScreen.updatePosition(v: 82);
      F(p + 1, 32) - (p + 2, 0, -61) >>
          (Display()
            ..setBitmap(image.bitmap)
            ..sprites = spriteScreen.labels
            ..spriteColorOffset = 240
            ..priority = 4);

      transition(trans, (p + 1, 32), backward: !reverse, inverse: reverse);
    }

    List<(int?, int)> aliceOffsets = List.filled(5, (null, 0));
    List<(int?, int)> aliceOffsetsFun(int t) {
      var l = aliceOffsets;
      if (t == 0) l[1] = (0, 0);
      if (t == 64 * 6) l[1] = (null, 0);
      return l;
    }

    List<(int?, int)> lisaOffsets = List.filled(5, (null, 0));
    List<(int?, int)> lisaOffsetsFun(int t) {
      var l = lisaOffsets;
      if (t == 0) l[2] = (0, 0);
      if (t == 64 * 6) l[2] = (null, 0);
      return l;
    }

    List<(int?, int)> paulaOffsets = List.filled(5, (null, 0));
    List<(int?, int)> paulaOffsetsFun(int t) {
      var l = paulaOffsets;
      if (t == 0) l[1] = (0, 0);
      if (t == 64 * 6) l[1] = (null, 0);
      return l;
    }

    girl(P, alice, aliceWords, lisaBg, -1, false, 2, aliceOffsetsFun);
    girl(P + 2, lisa, lisaWords, paulaBg, 1, true, 1, lisaOffsetsFun);
    girl(P + 4, paula, paulaWords, finalBg, -1, false, 3, paulaOffsetsFun);

    F(P + 6, 0, -1) >> Display();
  }
}
