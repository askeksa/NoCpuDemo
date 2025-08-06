import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../main.dart';
import '../effects/checkerboard.dart';

mixin Check on NoCpuDemoBase {
  Checkerboard checkerboard = Checkerboard(320, 180, 8, 82);

  void check(int P) {
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

    F(P, 0) - (P + 4, 0, -2) | frame;
    F(P + 4, 0, -1) >> Display();
  }
}
