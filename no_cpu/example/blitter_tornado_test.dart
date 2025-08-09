import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/blitter_tornado.dart';

main() {
  BlitterTornadoTest().build();
}

class BlitterTornadoTest extends DemoBase {
  BlitterTornado tornado = BlitterTornado();

  Palette planeColors = Palette.generate(4, (i) {
    double n = i / 4;
    return (i, Color.hsl(0.3, 1 - n, n));
  });

  BlitterTornadoTest() : super(500, loopFrame: 1) {
    F(0, 0, 0) << planeColors;

    F(0, 0, 0) << (Blit()..dSetInterleaved(tornado.bitmap1));

    F(0, 0, 1) << (Blit()..dSetInterleaved(tornado.bitmap2));

    F(0, 0, 2) - (0, 0, 499) |
        (int frame, Copper copper) {
          var tornadoFrame = tornado.frame(frame, 1.0, 1.02);

          var display = Display()
            ..horizontalScroll = BlitterTornado.borderLeft * 4
            ..verticalScroll = BlitterTornado.borderTop
            ..bitplanes = tornadoFrame.frontPlanes
            ..stride = tornadoFrame.front.rowStride;

          copper >> display;

          copper << tornadoFrame;
        };
  }
}
