import 'dart:io';
import 'dart:math';

import 'package:no_cpu/bitmap.dart';
import 'package:no_cpu/blitter.dart';
import 'package:no_cpu/copper.dart';
import 'package:no_cpu/custom.dart';
import 'package:no_cpu/display.dart';
import 'package:no_cpu/memory.dart';

main() {
  var chunky = ChunkyPixels.generate(
    315,
    175,
    (x, y) => (sqrt(x * x + y * y) / 10).toInt(),
  );
  var bitmap = Bitmap.fromChunky(chunky, depth: 2, interleaved: true);
  print(bitmap);

  Copper sub = Copper(origin: "Subroutine");
  sub.wait(v: 80, h: 7);
  sub.move(COLOR00, 0x0F0);

  List<Copper> frames = List.generate(
    16,
    (i) => Copper(isPrimary: true, origin: i),
  );
  for (var (i, frame) in frames.indexed) {
    var display =
        Display()
          ..setBitmap(bitmap)
          ..alignment = i % 3 + 1;
    frame >> display;

    var color = FreeLabel("color");
    var blit =
        Blit()
          ..adPtr = color
          ..adStride = 0
          ..aShift = 1
          ..height = 2;

    frame >> blit >> WaitBlit();
    frame.move(COLOR00, 0x005, label: color);

    frame.call(sub);
    frame.wait(v: 100, h: 7);
    frame << bg(i * 0x111);
    frame.wait(v: 200, h: 7);
    frame >> bg(i.isEven ? 0xA00 : 0x500);
    frame.ptr(COP1LC, frames[(i + 1) % frames.length].label);
  }

  Copper initialCopper = Copper(isPrimary: true, origin: "Initial")
    ..data.address = 0x00_0000;
  initialCopper.move(DIWSTRT, 0x5281);
  initialCopper.move(DIWSTOP, 0x06C1);
  initialCopper.move(COLOR01, 0x0531);
  initialCopper.move(COLOR02, 0x0741);
  initialCopper.move(COLOR03, 0x0951);
  initialCopper.ptr(COP1LC, frames[0].label);

  Memory m = Memory.fromRoots(0x20_0000, [initialCopper.data]);
  File("../runner/chip.dat").writeAsBytesSync(m.build());
}

class SetBackground implements CopperComponent {
  final int color;

  SetBackground(this.color);

  @override
  void addToCopper(Copper copper) {
    copper.move(COLOR00, color);
  }
}

SetBackground bg(int color) => SetBackground(color);
