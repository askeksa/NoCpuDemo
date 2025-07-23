import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/game_of_life.dart';

main() {
  GameOfLifeTest().build();
}

class GameOfLifeTest extends DemoBase {
  GameOfLife gameOfLife = GameOfLife(336, 180, 16, 0);

  GameOfLifeTest() : super(2, loopFrame: 0) {
    Random random = Random(DateTime.now().millisecondsSinceEpoch);
    Bitmap bitmap = Bitmap.generate(
      336,
      180,
      (x, y) => x >= 160 - 32 && x < 160 + 32 && y >= 90 - 32 && y < 90 + 32
          ? random.nextInt(2)
          : 0,
      depth: 1,
      mutability: Mutability.mutable,
    );
    Display display = Display()..setBitmap(bitmap);
    Palette palette = Palette.rgb12([0x025, 0x8af]);

    var blits = gameOfLife.step(bitmap);
    F(0, 0) - 1 << display << palette;
    F(0, 0, 0) << (blits.sublist(13) + blits.sublist(0, 9)).joined;
    F(0, 0, 1) << blits.sublist(9, 13).joined |
        (i, c) {
          c.waitBlit();
          c.move(BPLCON3, 0X0000);
          c.move(COLOR00, 0x333);
        };
  }
}
