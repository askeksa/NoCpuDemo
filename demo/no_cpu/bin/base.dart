import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' show dirname;

import 'package:no_cpu/no_cpu.dart';

class DemoBase {
  late final Copper initialCopper;
  List<Copper> frames = [];
  Copper? endCopper;

  int startFrame = 0;
  int? loopFrame;

  List<Block> roots = [];

  late String scriptPath = dirname(Platform.script.toFilePath());
  late String assetsPath = "$scriptPath/../../assets";
  late String runnerPath = "$scriptPath/../../../runner";
  late String outputFile = "$runnerPath/chip.dat";

  DemoBase(int frameCount, {this.loopFrame}) {
    initialCopper =
        Copper(isPrimary: true, origin: "Initial")
          ..data.address = 0x00_0000
          ..useInFrame(-1);
    roots.add(initialCopper.data);

    frames = List.generate(frameCount, (i) {
      return Copper(isPrimary: true, origin: i)..useInFrame(i);
    });
    roots.addAll(frames.map((f) => f.data));

    if (loopFrame == null) {
      endCopper = Copper(isPrimary: true, origin: "End");
      roots.add(endCopper!.data);
    }
    Copper finalCopper = endCopper ?? frames[loopFrame!];

    // Set up frame links in finalizers.
    initialCopper.finalizer = (c) => c.ptr(COP1LC, frames[startFrame].label);
    for (int i = 0; i < frames.length - 1; i++) {
      frames[i].finalizer = (c) => c.ptr(COP1LC, frames[i + 1].label);
    }
    frames.last.finalizer = (c) => c.ptr(COP1LC, finalCopper.label);

    // 320x180, borderblank
    initialCopper.move(DIWSTRT, 0x5281);
    initialCopper.move(DIWSTOP, 0x06C1);
    initialCopper.move(BPLCON3, 0x0020);
  }

  void build() {
    Memory m = Memory.fromRoots(0x20_0000, roots);
    m.finalize();
    print("Total data:  ${m.dataBlocks.map((b) => b.size).sum}");
    print("Total space: ${m.spaceBlocks.map((b) => b.size).sum}");
    var chipData = m.build();
    print("File size:   ${chipData.length}");
    File(outputFile).writeAsBytesSync(chipData);
  }
}
