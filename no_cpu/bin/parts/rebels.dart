import 'dart:math';

import 'package:collection/collection.dart';
import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';

mixin Rebels on NoCpuDemoBase {
  late IlbmImage aliceWordImage = IlbmImage.fromFile(
    "$assetsPath/Wordcloud Alice.iff",
  );
  late IlbmImage lisaWordImage = IlbmImage.fromFile(
    "$assetsPath/Wordcloud Lisa.iff",
  );
  late IlbmImage paulaWordImage = IlbmImage.fromFile(
    "$assetsPath/Wordcloud Paula.iff",
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
  late Color finalBg = togetherColor;

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

    SpriteGroup? parent;
    List<(int, int, SpriteGroup, Palette)> words = [];
    for (int i = 0; i < count; i++) {
      var (x, y, bitmap, pal) = wordBitmaps[i];
      int parity = i & 1;
      var sprite = SpriteGroup.fromBitmap(
        bitmap,
        baseIndex: parity,
        sameParity: true,
        parent: parent,
      );
      parent = sprite;
      words.add((x, y, sprite, sprite.palette(pal, 224, 240)));
    }

    return words;
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
      var imageBitmap = image.bitmap.crop(h: 180);

      // Slide girl in
      var padded = Bitmap.space(960, 180, 8, interleaved: true);
      F(p, 0, -63) - (p, 0, -61) << blankDisplay(image.palette[0]);
      F(p, 0, -63) << (Blit()..dSetInterleaved(padded, x: 0, w: 320));
      F(p, 0, -62) << (Blit()..dSetInterleaved(padded, x: 640, w: 320));
      F(p, 0, -61) <<
          (Blit()
            ..aSetInterleaved(imageBitmap, w: 320, h: 180)
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
      var range = image.colorRanges.single;
      int rangeSize = range.high - range.low + 1;
      var rangeData = Data(
        mutability: Mutability.mutable,
        origin: "Color cycle",
      );
      for (int i = range.low; i <= range.high; i++) {
        rangeData.addWord(image.palette[i].upper);
        rangeData.addWord(image.palette[i].lower);
      }
      var rangeLabel = rangeData.addLabel();
      for (int i = range.low; i <= range.high; i++) {
        rangeData.addWord(image.palette[0].upper);
        rangeData.addWord(image.palette[0].lower);
      }

      F(p, 0) - (p + 2, 0, -61) ^
          (i, f) {
            if (i % rate == 0) {
              f << DynamicPalette(rangeLabel, range.low, rangeSize);
              f <<
                  (Blit()
                    ..descending = true
                    ..aPtr = rangeData.label
                    ..dPtr = rangeData.label + 4
                    ..width = (2 * rangeSize - 1) * 2);
              f <<
                  (Blit()
                    ..aPtr = rangeLabel
                    ..dPtr = rangeData.label
                    ..width = 2);
            }
          };

      // Word cloud
      F(p, 0) - (p + 1, 32, -2) >>
              (Display()
                ..setBitmap(imageBitmap)
                ..sprites = words.first.$3.labels
                ..evenSpriteColorOffset = 224
                ..oddSpriteColorOffset = 240
                ..priority = 4) ^
          (i, f) => displayWords(f, words, offsets(i));
      F(p + 1, 32, -1) >> (Display()..setBitmap(imageBitmap));

      // Wipe
      F(p + 1, 32) >> spritePal(bg);
      F(p + 1, 32) - (p + 2, 0, -64) >>
          (Display()
            ..setBitmap(imageBitmap)
            ..sprites = spriteScreen.labels
            ..spriteColorOffset = 240
            ..priority = 4);

      transition(waveTrans, (p + 1, 32), backward: !reverse, inverse: reverse);
    }

    List<(int?, int)> aliceOffsets = List.filled(5, (null, 0));
    List<(int?, int)> aliceOffsetsFun(int t) {
      for (var (tt, i, x, y) in [
        (24, 1, 0, 0),
        (32, 0, 0, 0),
        (33, 0, null, 0),
        (34, 2, 0, 0),
        (35, 2, null, 0),
        (35, 3, 0, 0),
        (36, 3, null, 0),
        (36, 4, 0, 0),
        (38, 3, 0, 0),
        (39, 2, 0, 0),
        (40, 0, 0, 0),
        (84, 4, null, 0),
        (85, 3, null, 0),
        (86, 2, null, 0),
        (87, 0, null, 0),
        (88, 1, null, 0),
      ]) {
        if (t == tt * 6) aliceOffsets[i] = (x, y);
      }
      return aliceOffsets;
    }

    List<(int?, int)> lisaOffsets = List.filled(5, (null, 0));
    List<(int?, int)> lisaOffsetsFun(int t) {
      for (var (tt, i, x, y) in [
        (24, 2, 0, 0),
        (32, 0, 0, 0),
        (34, 4, 0, 0),
        (36, 1, 0, 0),
        (38, 3, 0, 0),
        (80, 0, null, 0),
        (82, 4, null, 0),
        (84, 1, null, 0),
        (86, 3, null, 0),
        (88, 2, null, 0),
      ]) {
        if (t == tt * 6) lisaOffsets[i] = (x, y);
      }
      return lisaOffsets;
    }

    List<(int?, int)> paulaOffsets = List.filled(5, (null, 0));
    List<(int?, int)> paulaOffsetsFun(int t) {
      for (var (tt, i, x, y) in [
        (24, 1, 0, 0),
        (32, 0, 0, 0),
        (40, 2, 0, 0),
        (48, 3, 0, 0),
        (56, 4, 0, 0),
        (84, 4, null, 0),
        (85, 3, null, 0),
        (86, 2, null, 0),
        (87, 0, null, 0),
        (88, 1, null, 0),
      ]) {
        if (t == tt * 6) paulaOffsets[i] = (x, y);
      }
      return paulaOffsets;
    }

    girl(P, alice, aliceWords, lisaBg, -1, false, 2, aliceOffsetsFun);
    girl(P + 2, lisa, lisaWords, paulaBg, 1, true, 1, lisaOffsetsFun);
    girl(P + 4, paula, paulaWords, finalBg, -1, false, 3, paulaOffsetsFun);

    F(P + 6, 0, -63) - (P + 6, 0, -49) << blankDisplay(finalBg);
  }
}
