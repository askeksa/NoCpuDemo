import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/checkerboard.dart';

main() {
  CheckerboardTest().build();
}

class CheckerboardTest extends DemoBase {
  Checkerboard checkerboard = Checkerboard(320, 180, 8, 82);

  CheckerboardTest() : super(256, loopFrame: 0) {
    (double, double) pos(int t) {
      double x = 900 * sin(2 * t * pi / 128);
      double y = 1500 * sin(1 * t * pi / 128);
      return (x, y);
    }

    Color col(int t) {
      var col1 = Color.rgb12(0xfa5);
      var col2 = Color.rgb12(0x78f);
      return col1.interpolate(col2, 0.5 + 0.5 * sin(121 * t * pi / 128));
    }

    void frame(int i, Copper f) {
      List<(int, int, int, Color)> layers = [];
      var (ix, iy) = pos(i);
      for (int t = (i + 127) & -16; t >= i; t -= 16) {
        var (x, y) = pos(t);
        int d = t - i;
        layers.add((
          ((x - ix) / (d + 5)).toInt(),
          ((y - iy) / (d + 5)).toInt(),
          d,
          col(t) * ((128 - d) / 128),
        ));
      }
      f << checkerboard.frame(layers);
    }

    F(0, 0) - 255 | frame;
  }
}
