import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/game_of_life.dart';

mixin Life on NoCpuDemoBase {
  GameOfLife gameOfLife = GameOfLife(320, 180, 2, 2);

  void life(int P) {
    int seed = DateTime.now().millisecondsSinceEpoch;
    print("Game of Life seed: $seed");
    Random random = Random(seed);
    Bitmap center = Bitmap.generate(
      32,
      32,
      depth: 1,
      (x, y) => random.nextInt(2),
    );
    Bitmap bitmap = Bitmap.space(320, 180, 1);
    Palette palette = Palette.rgb12([0x025, 0x8af]);

    IlbmImage qr = IlbmImage.fromFile("$assetsPath/QR CODE_IFF.iff");
    SpriteGroup qrSprite = SpriteGroup.fromBitmap(
      qr.bitmap.autocrop().$3,
      baseIndex: 6,
    );
    qrSprite.setPosition(
      v: 82 + 90 - qrSprite.height ~/ 2,
      h: 0x200 + (160 - qrSprite.width ~/ 2) * 4,
    );
    var qrPalette = qrSprite.palette(qr.palette.sub(1, 3), 240);

    Display transDisplay = Display()
      ..setBitmap(lifeTrans.result)
      ..sprites = qrSprite.labels
      ..spriteColorOffset = 240
      ..priority = 0;
    Display lifeDisplay = Display()
      ..setBitmap(bitmap)
      ..sprites = null
      ..spriteColorOffset = 240
      ..priority = 4;

    F(P - 1, 48) << (palette | Palette.fromMap({1: lifeColor}) | qrPalette);
    F(P - 1, 48) - (P, 0, -2) >> transDisplay;

    transition(lifeTrans, (P - 1, 48), end: 94);

    var blits = gameOfLife.step(bitmap);
    var noise = Blit()
      ..aSetBitplane(center, 0)
      ..cdSetBitplane(bitmap, 0, x: 160 - 16, y: 90 - 16, w: 32, h: 32);

    F(P, 0, -1) << (Blit()..dSetBitplane(bitmap, 0));
    F(P, 0, -1) - (P + 1, 63, 5) >> lifeDisplay;
    F(P, 0, -1) << (palette | qrPalette);
    F(P, 0, -2) - 1 |
        (i, f) {
          f.wait(v: 0xFF, h: 0xDF);
          f.wait(v: 0x30);
          f >> SpritePointers(qrSprite.labels);
        };
    F(P, 0) - (P + 1, 63, 5) ^
        (i, copper) {
          if (i % 6 == 0) {
            // Center noise
            copper << noise;
          }
          if (i % 2 == 0) {
            copper << blits.sublist(13) + blits.sublist(0, 9);
          } else {
            copper << blits.sublist(9, 13);
          }

          // HACK: Set sprite pointers at the end of the frame
          copper >> SpritePointers(qrSprite.labels);
        };
  }
}
