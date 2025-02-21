import 'dart:io';

import 'package:no_cpu/copper.dart';
import 'package:no_cpu/custom.dart';
import 'package:no_cpu/memory.dart';
import 'package:no_cpu/music.dart';

main() {
  // Dummy music
  Data samples = Data()
    ..addBytes([0, 0, for (int i = 0; i < 6400; i++) (i * 4) & 0xFF]);
  Instrument instrument = Instrument(samples, 0, 2);
  Music music = Music()
    ..frames.add(MusicFrame()
      ..channels = [
        MusicFrameChannel()
          ..trigger = InstrumentTrigger(instrument)
          ..period = 150
          ..volume = 42,
        MusicFrameChannel(),
        MusicFrameChannel(),
        MusicFrameChannel(),
      ]);

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
  File("../runner/chip.dat").writeAsBytesSync(m.build());
}
