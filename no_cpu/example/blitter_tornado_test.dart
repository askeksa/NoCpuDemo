import 'dart:math';

import 'package:collection/collection.dart';
import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/blitter_tornado.dart';

main() {
  BlitterTornadoTest().build();
}

class BlitterTornadoTest extends DemoBase {
  BlitterTornado tornado = BlitterTornado();

  Palette palette = Palette.generate(2, (i) => (i, Color.rgb8(i * 255, i * 255, i * 255)));

  BlitterTornadoTest() : super(500, loopFrame: 0) {
    F(0, 0) - 499 |
      (int frame, Copper copper) {
        if (frame == 0) {
          copper << palette;
        }

        copper << tornado.frame(frame, 1.0, 1.02);
      };
  }
}
