import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../main.dart';
import '../effects/game_of_life.dart';

mixin Life on NoCpuDemoBase {
  GameOfLife gameOfLife = GameOfLife(320, 180, 2, 2);

  void life(int P) {
    Random random = Random(DateTime.now().millisecondsSinceEpoch);
    Bitmap center = Bitmap.generate(
      32,
      32,
      depth: 1,
      (x, y) => random.nextInt(2),
    );
    Bitmap bitmap = Bitmap.space(320, 180, 1);
    Display display = Display()..setBitmap(bitmap);
    Palette palette = Palette.rgb12([0x025, 0x8af]);

    F(P, 0, -1) << palette;
    F(P, 0, -1) << (Blit()..dSetBitplane(bitmap, 0));

    var blits = gameOfLife.step(bitmap);
    var noise = Blit()
      ..aSetBitplane(center, 0)
      ..cdSetBitplane(bitmap, 0, x: 160 - 16, y: 90 - 16, w: 32, h: 32);

    F(P, 0) - (P + 1, 63, 5) >> display;
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
        };
  }
}
