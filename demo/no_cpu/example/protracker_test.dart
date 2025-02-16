import 'dart:io';

import 'package:no_cpu/copper.dart';
import 'package:no_cpu/custom.dart';
import 'package:no_cpu/memory.dart';
import 'package:no_cpu/protracker.dart';
import 'package:no_cpu/protracker_player.dart';

main() {
  //var module = ProtrackerModule.readFromFile("no_cpu/example/ocean.mod");
  var module = ProtrackerModule.readFromFile("no_cpu/example/occ-san-geen.mod");
  //var module = ProtrackerModule.readFromFile("no_cpu/example/nocpu.mod");
  //var module = ProtrackerModule.readFromFile("no_cpu/example/Blue_Monday.mod");
  //var module = ProtrackerModule.readFromFile("no_cpu/example/Klisje_paa_Klisje.mod");
  var music = ProtrackerPlayer(module).toMusic();

  // Copperlists
  Copper initialCopper = Copper(isPrimary: true, origin: "Initial")
    ..data.address = 0x00_0000;
  Copper prev = initialCopper;
  List<Copper> frames = List.generate(music.frames.length, (i) {
    Copper frame = Copper(isPrimary: true, origin: i);
    frame >> music.frames[i];
    prev.ptr(COP1LC, frame.label);
    prev = frame;
    return frame;
  });
  Copper endCopper = music.restart != null
      ? frames[music.restart!]
      : Copper(isPrimary: true, origin: "End");
  prev.ptr(COP1LC, endCopper.label);

  // Memory
  Memory m = Memory.fromRoots(0x20_0000, [initialCopper.data]);
  File("../runner/chip.dat").writeAsBytesSync(m.finalize());
}
