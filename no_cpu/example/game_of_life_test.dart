import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/game_of_life.dart';

main() {
  GameOfLifeTest().build();
}

class GameOfLifeTest extends DemoBase {
  GameOfLife gameOfLife = GameOfLife(336, 180, 16, 0);

  GameOfLifeTest() : super(6, loopFrame: 0) {
    Random random = Random(DateTime.now().millisecondsSinceEpoch);
    Bitmap center = Bitmap.generate(
      32,
      32,
      depth: 1,
      (x, y) => random.nextInt(2),
    );
    Bitmap bitmap = Bitmap.space(336, 180, 1);
    initialCopper << (Blit()..dSetBitplane(bitmap, 0));

    Display display = Display()..setBitmap(bitmap);
    Palette palette = Palette.rgb12([0x025, 0x8af]);

    var blits = gameOfLife.step(bitmap);
    F(0, 0) - 5 << display << palette;
    F(0, 0, 0) <<
        (Blit()
          ..aSetBitplane(center, 0)
          ..cdSetBitplane(bitmap, 0, x: 160 - 16, y: 90 - 16, w: 32, h: 32));
    F(0, 0, 0) + 2 + 2 << (blits.sublist(13) + blits.sublist(0, 9));
    F(0, 0, 1) + 2 + 2 << blits.sublist(9, 13) |
        (i, c) {
          c.waitBlit();
          c.move(BPLCON3, 0X0000);
          c.move(COLOR00, 0x333);
        };
  }
}
