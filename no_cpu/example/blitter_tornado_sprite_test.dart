import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/blitter_tornado.dart';

main() {
  BlitterTornadoTest().build();
}

class BlitterTornadoTest extends DemoBase {
  var tornado = BlitterTornado();
  var spriteGroup = SpriteGroup.blank(320, 180);
  var blankBitmap = Bitmap.blank(320, 1, 1);

  Palette planeColors = Palette.generate(3, (i) {
    i += 1;
    double n = i / 4;
    return (i, Color.hsl(0.3, 1 - n, n));
  });

  BlitterTornadoTest() : super(500, loopFrame: 1) {
    var spritePalette = spriteGroup.palette(planeColors, 240);

    F(0, 0, 0) << spritePalette;
    F(0, 0, 0) << spriteGroup.updatePosition(v: 82);
    F(0, 0, 0) << spriteGroup.updateTerminator();

    F(0, 0, 0) << (Blit()..dSetInterleaved(tornado.bitmap1));

    F(0, 0, 1) << (Blit()..dSetInterleaved(tornado.bitmap2));

    F(0, 0, 2) - (0, 0, 499) |
        (int frame, Copper copper) {
          copper.move(BPLCON3, 0x000);
          copper.move(COLOR00, 0x000);

          var tornadoFrame = tornado.frame(frame, 1.0, 1.02);

          var display = Display()
            ..sprites = spriteGroup.labels
            ..setBitmap(blankBitmap)
            ..spriteColorOffset = 240
            ..evenStride = 0;

          copper >> display;

          copper >>
              spriteGroup.blit(
                0,
                aBitmap: tornado.frontForFrame(frame),
                aFromPlane: 0,
                x: BlitterTornado.borderLeft,
                y: BlitterTornado.borderTop,
              );
          copper >>
              spriteGroup.blit(
                1,
                aBitmap: tornado.frontForFrame(frame),
                aFromPlane: 1,
                x: BlitterTornado.borderLeft,
                y: BlitterTornado.borderTop,
              );

          copper << tornadoFrame;

          copper.move(COLOR00, 0xFFF);
        };
  }
}
