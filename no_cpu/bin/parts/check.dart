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
      if (t > 1535) {
        return Color.rgb12(0x000);
      }
      var col1 = Color.rgb12(0xfa5);
      var col2 = Color.rgb12(0x78f);
      return col1.interpolate(col2, 0.5 + 0.5 * sin(121 * t * pi / 128));
    }

    void frame(int i, Copper f) {
      List<(int, int, int, Color)> layers = [];
      var (ix, iy) = pos(i);
      for (int l = 0; l < 8; l++) {
        int t = max((i + 127) & -16, 256) - l * 16;
        var (x, y) = pos(t);
        var color = col(t);
        int d = t - i;
        if (d > 127) {
          d = 127;
          color = Color.rgb12(0x000);
        }
        layers.add((
          ((x - ix) / (d + 5)).toInt(),
          ((y - iy) / (d + 5)).toInt(),
          d,
          color * ((128 - d) / 128),
        ));
      }
      f << checkerboard.frame(layers);
    }

    F(P - 1, 0, 0) - (P, 0, -1) << blankDisplay(Color.rgb12(0x000));

    F(P, 0) - (P + 4, 0, -2) | frame;
    F(P + 4, 0, -1) >> Display();
  }
}
