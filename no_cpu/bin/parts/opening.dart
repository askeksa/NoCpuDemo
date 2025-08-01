import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';

mixin Opening on NoCpuDemoBase {
  void ratingCard(int P) {
    var image = IlbmImage.fromFile("$assetsPath/Folcka_NO CPU WARNING.iff");
    F(P, 0) >> image.palette;
    F(P, 0) - (P + 1, 0, -1) >> (Display()..setBitmap(image.bitmap));
    F(P + 1, 0) >> Display();
  }
}
