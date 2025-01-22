import 'dart:io';

import 'package:no_cpu/memory.dart';
import 'package:no_cpu/copper.dart';
import 'package:no_cpu/custom.dart';

main() {
  var m = Memory(0x20_0000);

  Copper sub = m.copper(origin: "Subroutine");
  sub.wait(v: 80, h: 7);
  sub.move(COLOR00, 0x0F0);
  sub.ret();

  List<Copper> frames =
      List.generate(16, (i) => m.copper(isPrimary: true, origin: i));
  for (var (i, frame) in frames.indexed) {
    frame.move(COLOR00, 0x005);
    frame.call(sub);
    frame.wait(v: 100, h: 7);
    frame << bg(i * 0x111);
    frame.wait(v: 200, h: 7);
    frame >> bg(i.isEven ? 0xA00 : 0x500);
    frame.ptr(COP1LC, frames[(i + 1) % frames.length].label);
    frame.end();
  }

  Copper initialCopper = m.copper(origin: "Initial")..data.address = 0x00_0000;
  initialCopper.ptr(COP1LC, frames[0].label);
  initialCopper.end();

  File("../runner/chip.dat").writeAsBytesSync(m.finalize());

  print("Number of cached copper components: ${m.copperComponentCache.length}");
}

class SetBackground implements CacheableCopperComponent {
  final int color;

  SetBackground(this.color);

  @override
  void addToCopper(Copper copper) {
    copper.move(COLOR00, color);
  }

  @override
  bool operator ==(Object other) =>
      other is SetBackground && other.color == color;

  @override
  int get hashCode => color;
}

SetBackground bg(int color) => SetBackground(color);
