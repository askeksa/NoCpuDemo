import 'dart:io';
import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

main() {
  var chunky = ChunkyPixels.generate(
    315,
    175,
    (x, y) => (sqrt(x * x + y * y) / 3).toInt(),
  );
  var bitmap = Bitmap.fromChunky(
    chunky,
    depth: 6,
    interleaved: true,
    mutability: Mutability.local,
  );
  print(bitmap);

  Copper sub = Copper(origin: "Subroutine");
  sub.wait(v: 80, h: 7);
  sub.move(COLOR00, 0x0F0);

  List<Copper> frames = List.generate(
    16,
    (i) =>
        Copper(isPrimary: true, origin: i)
          ..useInFrame(i)
          ..mutability = Mutability.mutable,
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

  frames[8] <<
      (Blit()
        ..aSetInterleaved(bitmap, x: 42, y: 42, w: 42, h: 42)
        ..cdSetInterleaved(bitmap, x: 122, y: 87, w: 42, h: 42));

  Copper initialCopper =
      Copper(isPrimary: true, origin: "Initial")
        ..data.address = 0x00_0000
        ..useInFrame(-1);
  initialCopper.move(DIWSTRT, 0x5281);
  initialCopper.move(DIWSTOP, 0x06C1);
  initialCopper <<
      Palette.generateRange(
        1,
        63,
        (i) => Color.rgb8(100 + i * 2, i * 3, i * 4),
      );
  initialCopper.move(BPLCON3, 0x0000);
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
