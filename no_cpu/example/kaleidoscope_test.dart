import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/kaleidoscope_32.dart';

main() {
  KaleidoscopeTest().build();
}

class KaleidoscopeTest extends DemoBase {
  static final cycleLength = 128;
  late final Kaleidoscope _kaleidoscope1 = Kaleidoscope()
    ..pattern1 = 1
    ..pattern2 = 0;

  late final Kaleidoscope _kaleidoscope2 = Kaleidoscope()
    ..pattern1 = 2
    ..reversePattern1 = true
    ..pattern2 = 1;

  late final Kaleidoscope _kaleidoscope3 = Kaleidoscope()
    ..pattern1 = 0
    ..pattern2 = 2;

  late final _kaleidoscope = _kaleidoscope3;

  final _blankBitmap = Bitmap.blank(320, 1, 1);

  final _colors = [
    Color.hsl(0.60, 0.4, 0.2),
    Color.hsl(0.61, 0.4, 0.3),
    Color.hsl(0.62, 0.4, 0.3),
    Color.hsl(0.615, 0.4, 0.25),
  ];

  late final _palette = Palette.generate(16, (i) => (i + 240, _colors[i % 4]))
    ..[0] = _colors[0];

  KaleidoscopeTest() : super(cycleLength + 2, loopFrame: 2) {
    F(0, 0, 0) << _palette;

    F(0, 0, 0) - 1 |
        ((frame, copper) {
          copper << _kaleidoscope.init(frame);
        });

    F(0, 0, 2) - (cycleLength - 1) |
        ((frame, copper) {
          //copper.move(BPLCON3, 0x000);
          //copper.move(COLOR00, 0x000);

          var kaleidoscopeFrame = _kaleidoscope.frame(frame);
          var footer = _kaleidoscope.footer(frame);

          copper >>
              (_kaleidoscope.displayForFrame(frame)
                ..setBitmap(_blankBitmap)
                ..spriteColorOffset = 240
                ..evenStride = 0);

          copper >> kaleidoscopeFrame;
          copper >> footer;

          //copper.move(COLOR00, 0xFFF);
        });
  }
}
