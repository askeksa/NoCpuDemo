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

    var image = IlbmImage.fromFile("$assetsPath/Folcka_EVIL CPU.iff");

    SpriteGroup spriteScreen = SpriteGroup.space(320, 180);
    var spritePalette = spriteScreen.palette(Palette.fromMap({1: from}));

    F(P, 0) >> (image.palette | spritePalette);
    F(P, 0) >> spriteScreen.updatePosition(v: 82);

    F(P, 0) - (P + 2, 0, -1) >>
        (Display()
          ..setBitmap(image.bitmap)
          ..sprites = spriteScreen.labels
          ..priority = 4);
    F(P, 0) - 127 >> spriteScreen.blit(0, aBitmap: trans.result);
    F(P, 0, -1) - 127 | (i, f) => f << trans.run(i);

    F(P + 2, 0) >> Display();
  }
}
