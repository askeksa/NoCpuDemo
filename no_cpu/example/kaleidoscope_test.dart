import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/kaleidocope.dart';

main() {
  KaleidoscopeTest().build();
}

class KaleidoscopeTest extends DemoBase {
  final Kaleidoscope _kaleidoscope = Kaleidoscope();
  final _blankBitmap = Bitmap.blank(320, 1, 1);

  final Palette _palette =
      (Palette.generate(16, (i) {
          double n = (i % 4) / 4;
          return (i + 240, Color.hsl(0.3, 0.5, n / 2));
        })
        ..[0] = Color.black
        ..[1] = Color.white);

  KaleidoscopeTest() : super(32, loopFrame: 2) {
    F(0, 0, 0) << _palette;

    F(0, 0, 0) - 1 |
        ((frame, copper) {
          copper << _kaleidoscope.init(frame);
        });

    F(0, 0, 2) - 29 |
        ((frame, copper) {
          //copper.move(BPLCON3, 0x000);
          //copper.move(COLOR00, 0x000);

          var kaleidoscopeFrame = _kaleidoscope.frame(frame);

          copper >>
              (_kaleidoscope.displayForFrame(frame)
                ..setBitmap(_blankBitmap)
                ..spriteColorOffset = 240
                ..evenStride = 0);

          copper >> kaleidoscopeFrame;

          //copper.move(COLOR00, 0xFFF);
        });
  }
}
