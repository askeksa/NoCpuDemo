import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/transition.dart';

mixin Bully on NoCpuDemoBase {
  void bully(int P, Color from) {
    var trans = Transition.generate(320, 180, (x, y) {
      double dx = x - 160;
      double dy = y - 100;
      return sqrt(dx * dx + dy * dy) * 0.4;
    });

    var image = IlbmImage.fromFile("$assetsPath/EVIL CPU 5.iff");
    var bitmap = image.bitmap.crop(h: 180, depth: 6);
    var bitmaps = [
      for (int i = 0; i < 3; i++)
        bitmap.transform((_, _, p) => p >> i * 2, depth: 2, interleaved: true),
    ];
    var spritePalette = spriteScreen.palette(Palette.fromMap({1: from}));

    F(P, 0) >> (image.palette | spritePalette);
    F(P, 0) >> spriteScreen.updatePosition(v: 82);

    F(P, 0) - (P + 2, 0, -2) >>
        (Display()
          ..bitplanes = [
            for (int i = 0; i < 6; i++)
              bitmaps[i >> 1].bitplanes + (i & 1) * bitmap.bytesPerRow,
          ]
          ..stride = bitmap.bytesPerRow * 2
          ..sprites = spriteScreen.labels
          ..priority = 4);

    transition(trans, (P, 0));

    F(P + 2, 0, -1) >> Display();
  }
}
