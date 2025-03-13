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

    for (final (i, f) in frames.indexed) {
      f >> (Display()..setBitmap(result));
      f.wait(v: 0x54);
      if (i < 128) {
        f << trans1.run(i, inverse: true);
      } else {
        f << trans2.run(256 - i, inverse: true);
      }
    }

    initialCopper.move(COLOR00, 0x205);
    initialCopper.move(COLOR01, 0xa85);
  }
}
