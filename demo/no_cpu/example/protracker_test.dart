import 'dart:io';

import 'package:collection/collection.dart';

import 'package:no_cpu/copper.dart';
import 'package:no_cpu/custom.dart';
import 'package:no_cpu/memory.dart';
import 'package:no_cpu/protracker.dart';
import 'package:no_cpu/protracker_player.dart';

main(List<String> args) {
  if (args.isEmpty) {
    print("Usage: protracker_test file.mod");
    return;
  }

  print("Module size:  ${File(args[0]).lengthSync()}");
  var module = ProtrackerModule.readFromFile(args[0]);
  var music = ProtrackerPlayer(module).toMusic();

  // Copperlists
  Copper initialCopper =
      Copper(isPrimary: true, origin: "Initial")
        ..data.address = 0x00_0000
        ..useInFrame(-1);
  Copper prev = initialCopper;
  List<Copper> frames = List.generate(music.frames.length, (i) {
    Copper frame = Copper(isPrimary: true, origin: i)..useInFrame(i);
    frame >> music.frames[i];
    prev.ptr(COP1LC, frame.label);
    prev = frame;
    return frame;
  });
  Copper endCopper =
      music.restart != null
          ? frames[music.restart!]
          : Copper(isPrimary: true, origin: "End");
  prev.ptr(COP1LC, endCopper.label);

  // Memory
  Memory m = Memory.fromRoots(0x20_0000, [initialCopper.data]);
  m.finalize();
  print("Before dedup: ${m.dataBlocks.map((b) => b.size).sum}");
  var chipData = m.build();
  print("After dedup:  ${chipData.length}");
  File("../runner/chip.dat").writeAsBytesSync(chipData);
}
