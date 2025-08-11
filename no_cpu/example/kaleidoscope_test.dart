import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/kaleidocope.dart';

main() {
  KaleidoscopeTest().build();
}

class KaleidoscopeTest extends DemoBase {
  final Kaleidoscope _kaleidoscope = Kaleidoscope();

  final Palette _palette = Palette.generate(1 << Kaleidoscope.depth, (i) {
    double n = i / (1 << Kaleidoscope.depth);
    return (i, Color.hsl(0.3, 0.5, n / 2));
  });

  KaleidoscopeTest() : super(1500, loopFrame: 1) {
    F(0, 0, 0) << _palette;

    F(0, 0, 0) - 1 |
        ((frame, copper) {
          copper << _kaleidoscope.init(frame);
        });

    F(0, 0, 2) - (1499 - 2) |
        ((frame, copper) {
          copper >>
              (Display()
                ..setBitmap(_kaleidoscope.frontForFrame(frame))
                ..verticalScroll = 8);

          copper << _kaleidoscope.frame(frame);
        });
  }
}
