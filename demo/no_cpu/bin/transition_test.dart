import 'dart:io';
import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import 'effects/transition.dart';

main() {
  var trans1 = Transition.generate(320, 180, (x, y) {
    var dx = x - 80;
    var dy = y - 80;
    return 20 +
        sqrt(dx * dx + dy * dy) * 0.28 +
        (cos(x * 0.3) + cos(y * 0.3)) * 10;
  });
  var trans2 = Transition.generate(320, 180, (x, y) {
    return 20 +
        x * (0.2 + y * 0.001) -
        y * 0.1 +
        (sin(y * 0.11 + x * 0.013) + sin(y * 0.13 - x * 0.015)) * 5;
  });
  var result = trans1.result = trans2.result;

  List<Copper> frames = List.generate(
    256,
    (i) => Copper(isPrimary: true, origin: i)..useInFrame(i),
  );
  for (var (i, frame) in frames.indexed) {
    frame >> (Display()..setBitmap(result));
    frame.wait(v: 0x54);
    if (i < 128) {
      frame << trans1.run(i, inverse: true);
    } else {
      frame << trans2.run(256 - i, inverse: true);
    }
    frame.ptr(COP1LC, frames[(i + 1) % frames.length].label);
  }

  Copper initialCopper =
      Copper(isPrimary: true, origin: "Initial")
        ..data.address = 0x00_0000
        ..useInFrame(-1);
  initialCopper.move(DIWSTRT, 0x5281);
  initialCopper.move(DIWSTOP, 0x06C1);
  initialCopper.move(BPLCON3, 0x0020);
  initialCopper.move(COLOR00, 0x205);
  initialCopper.move(COLOR01, 0xa85);
  initialCopper.ptr(COP1LC, frames[0].label);

  Memory m = Memory.fromRoots(0x20_0000, [initialCopper.data]);
  File("../runner/chip.dat").writeAsBytesSync(m.build());
}
