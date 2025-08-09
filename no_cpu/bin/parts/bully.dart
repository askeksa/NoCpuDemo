import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/blitter_tornado.dart';
import '../effects/transition.dart';

mixin Bully on NoCpuDemoBase {
  static final _horizontalPadding = 64;

  void bully(int P, Color from) {
    var tornado = BlitterTornado();

    var trans = Transition.generate(320, 180, (x, y) {
      double dx = x - 160;
      double dy = y - 100;
      return sqrt(dx * dx + dy * dy) * 0.4;
    });

    var image = IlbmImage.fromFile("$assetsPath/EVIL CPU 5.iff");
    var imagePalette = image.palette.sub(0, 63);
    var bitmap = image.bitmap.crop(
      w: 320 + _horizontalPadding,
      h: 180,
      depth: 6,
    );
    var bitmaps = [
      for (int i = 0; i < 3; i++)
        bitmap.transform((_, _, p) => p >> i * 2, depth: 2, interleaved: true),
    ];
    var spritePalette = spriteScreen.palette(Palette.fromMap({1: from}));

    F(P, 0) >> (imagePalette | spritePalette);
    F(P, 0) >> spriteScreen.updatePosition(v: 82);

    F(P, 0) - (P, 0, 127) >>
        (Display()
          ..bitplanes = [
            for (int i = 0; i < 6; i++)
              bitmaps[i >> 1].bitplanes + (i & 1) * bitmap.bytesPerRow,
          ]
          ..stride = bitmap.bytesPerRow * 2
          ..sprites = spriteScreen.labels
          ..priority = 4);

    Palette interferencePalette =
        imagePalette |
        imagePalette.shift(64) |
        imagePalette.shift(128) |
        imagePalette.shift(192) |
        Palette.generate(4, (i) => (i * 64, imagePalette[0].interpolate(Color.white, i * 0.2)));

    F(P, 0, 128) >> interferencePalette;

    F(P, 0, 128) - (P + 2, 0, -2) |
        (frame, copper) {
          var tornadoFrame = tornado.frame(frame, 1.0, 1.02);
          var display = (Display()
            ..bitplanes = [
              for (int i = 0; i < 6; i++)
                bitmaps[i >> 1].bitplanes + (i & 1) * bitmap.bytesPerRow,
              ...tornadoFrame.frontPlanes,
            ]
            ..stride = bitmap.bytesPerRow * 2
            ..priority = 4);
          copper >> display;
          copper << tornadoFrame;
        };

    transition(trans, (P, 0));

    F(P + 2, 0, -1) >> Display();
  }
}
