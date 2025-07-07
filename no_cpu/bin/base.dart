import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' show dirname;

import 'package:no_cpu/no_cpu.dart';

String scriptPath = dirname(Platform.script.toFilePath());
String assetsPath = "$scriptPath/../../assets";
String runnerPath = "$scriptPath/../../../runner";
String outputFile = "$runnerPath/chip.dat";

class DemoBase {
  late final Copper initialCopper;
  List<Copper> frames = [];
  late final Copper endCopper;

  int startFrame = 0;
  int? loopFrame;

  List<Block> roots = [];

  int getTimestamp(int position, int row) {
    // Dummy timestamp for demos without music.
    return (position * 64 + row) * 6;
  }

  FrameScheduler F(int position, int row, [int offset = 0]) {
    return FrameScheduler(this, [frames[getTimestamp(position, row) + offset]]);
  }

  DemoBase(int frameCount, {this.loopFrame}) {
    initialCopper = Copper(isPrimary: true, origin: "Initial")
      ..data.address = 0x00_0000
      ..useInFrame(-1);
    roots.add(initialCopper.data);

    frames = List.generate(frameCount, (i) {
      return Copper(isPrimary: true, origin: i)..useInFrame(i);
    });
    roots.addAll(frames.map((f) => f.data));

    endCopper = Copper(isPrimary: true, origin: "End");
    if (loopFrame == null) {
      roots.add(endCopper.data);
    }
    Copper finalCopper = loopFrame != null ? frames[loopFrame!] : endCopper;

    // Set up frame links in finalizers.
    initialCopper.finalizer = (c) => c.ptr(COP1LC, frames[startFrame].label);
    for (int i = 0; i < frames.length - 1; i++) {
      frames[i].finalizer = (c) => c.ptr(COP1LC, frames[i + 1].label);
    }
    frames.last.finalizer = (c) => c.ptr(COP1LC, finalCopper.label);

    // Enable sprites, 320x180, borderblank
    initialCopper.move(DMACON, 0x8020);
    initialCopper.move(DIWSTRT, 0x5281);
    initialCopper.move(DIWSTOP, 0x06C1);
    initialCopper.move(BPLCON3, 0x0020);
    initialCopper >> Display();

    // Request demo exit by clearing Blitter Nasty.
    // Also clear bitplane and sprite DMA to blank the screen.
    endCopper.move(DMACON, 0x052F);
    endCopper.move(BPLCON3, 0x0020);
    endCopper.move(COLOR00, 0x000);
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

class MusicDemoBase extends DemoBase {
  final Music music;

  @override
  int getTimestamp(int position, int row) {
    return music.getTimestamp(position, row);
  }

  MusicDemoBase(this.music)
    : super(music.frames.length, loopFrame: music.restart) {
    for (int i = 0; i < frames.length; i++) {
      frames[i] >> music.frames[i];
    }
  }

  MusicDemoBase.withProtrackerFile(String filename)
    : this(ProtrackerPlayer(ProtrackerModule.readFromFile(filename)).toMusic());
}

extension FrameIndex on Copper {
  int get index {
    if (this.isPrimary && this.origin is int) {
      return this.origin as int;
    } else {
      throw Exception("'$this' is not a frame copperlist");
    }
  }
}

class FrameScheduler {
  final DemoBase demo;
  final List<Copper> frames;

  FrameScheduler(this.demo, this.frames);

  int _frame(Object f) {
    int frame = switch (f) {
      (int p, int r) => demo.getTimestamp(p, r),
      (int p, int r, int o) => demo.getTimestamp(p, r) + o,
      int i => frames.last.index + i,
      _ => throw Exception("Invalid frame specifier: $f"),
    };
    if (frame <= frames.last.index) {
      throw Exception(
        "Frame $f is before the last frame by ${frames.last.index - frame}",
      );
    }
    return frame;
  }

  FrameScheduler operator +(Object f) {
    int frame = _frame(f);
    frames.add(demo.frames[frame]);
    return this;
  }

  FrameScheduler operator -(Object f) {
    int frame = _frame(f);
    for (int i = frames.last.index + 1; i <= frame; i++) {
      frames.add(demo.frames[i]);
    }
    return this;
  }

  FrameScheduler operator <<(CopperComponent component) {
    for (final f in frames) {
      f << component;
    }
    return this;
  }

  FrameScheduler operator >>(CopperComponent component) {
    for (final f in frames) {
      f >> component;
    }
    return this;
  }

  FrameScheduler operator >>>(List<CopperComponent> components) {
    for (final (i, f) in frames.indexed) {
      f >> components[i % components.length];
    }
    return this;
  }

  FrameScheduler operator |(void Function(int, Copper) callback) {
    for (final (i, f) in frames.indexed) {
      f | (c) => callback(i, c);
    }
    return this;
  }

  FrameScheduler operator ^(void Function(int, Copper) callback) {
    for (final (i, f) in frames.indexed) {
      f ^ (c) => callback(i, c);
    }
    return this;
  }
}
