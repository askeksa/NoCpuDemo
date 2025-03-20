import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/transition.dart';

main() {
  TransitionTest().build();
}

class TransitionTest extends DemoBase {
  Transition trans1 = Transition.generate(320, 180, (x, y) {
    var dx = x - 80;
    var dy = y - 80;
    return 20 +
        sqrt(dx * dx + dy * dy) * 0.28 +
        (cos(x * 0.3) + cos(y * 0.3)) * 10;
  });
  Transition trans2 = Transition.generate(320, 180, (x, y) {
    return 20 +
        x * (0.2 + y * 0.001) -
        y * 0.1 +
        (sin(y * 0.11 + x * 0.013) + sin(y * 0.13 - x * 0.015)) * 5;
  });

  TransitionTest() : super(256, loopFrame: 0) {
    var result = trans1.result = trans2.result;

    F(0, 0) - 255 >> (Display()..setBitmap(result)) | (i, f) => f.wait(v: 0x54);
    F(0, 0) - 127 | (i, f) => f << trans1.run(i, inverse: true);
    F(0, 0, 128) - 127 | (i, f) => f << trans2.run(128 - i, inverse: true);

    initialCopper << Palette.rgb12([0x205, 0xa85]);
  }
}
