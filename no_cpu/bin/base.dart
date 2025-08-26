import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' show dirname;
import 'package:sprintf/sprintf.dart';

import 'package:no_cpu/no_cpu.dart';

String scriptPath = dirname(Platform.script.toFilePath());
String assetsPath = "$scriptPath/../../assets";
String runnerPath = "$scriptPath/../../../NoCpuChallenge/runner";
String outputFile = "$runnerPath/chip.dat";

class DemoBase {
  late final Copper initialCopper;
  List<Copper> frames = [];
  late final Copper endCopper;

  int? loopFrame;

  List<Block> roots = [];

  int getTimestamp(int position, int row) {
    // Dummy timestamp for demos without music.
    return (position * 64 + row) * 6;
  }

  CopperComponent getMusicFrame(int f) {
    // Dummy music frame for demos without music.
    return EmptyCopperComponent();
  }

  FrameScheduler F(int position, int row, [int offset = 0]) {
    return FrameScheduler(this, [frames[getTimestamp(position, row) + offset]]);
  }

  DemoBase(int frameCount, {this.loopFrame, int startFrame = 0}) {
    initialCopper = Copper(isPrimary: true, origin: "Initial")
      ..data.address = 0x00_0000
      ..useInFrame(-1);
    roots.add(initialCopper.data);

    frames = List.generate(frameCount, (i) {
      return Copper(isPrimary: true, alignment: 5, origin: i)..useInFrame(i);
    });

    List<Copper> musicFrames = List.generate(frameCount, (i) {
      return Copper.from(getMusicFrame(i), alignment: 5)..useInFrame(i);
    });

    var frameData = Data(singlePage: true, origin: "Frame dispatch");
    for (int f = 0; f < frameCount - 1; f++) {
      frameData.addReference(musicFrames[f + 1].label, 5);
      frameData.addReference(frames[f].label, 5);
      frameData.addLow(frameData.label + (f + 1) * 6);
    }
    if (loopFrame != null) {
      // Loop back to loopFrame.
      frameData.addReference(musicFrames[loopFrame!].label, 5);
      frameData.addReference(frames[frameCount - 1].label, 5);
      frameData.addLow(frameData.label + loopFrame! * 6);
    } else {
      // Request demo exit by clearing Blitter Nasty.
      // Also clear bitplane and sprite DMA to blank the screen.
      endCopper = Copper(origin: "End");
      endCopper.move(DMACON, 0x052F);
      endCopper.move(BPLCON3, 0x0020);
      endCopper.move(COLOR00, 0x000);
      endCopper.end();

      frameData.addReference(endCopper.label, 5);
      frameData.addReference(frames[frameCount - 1].label, 5);
      frameData.addLow(frameData.label + (frameCount - 1) * 6);
    }

    var ptrMask = Data.fromWords([0x001F, 0xFFE0], origin: "Pointer mask");

    var dispatchCopper =
        Copper(
            isPrimary: true,
            mutability: Mutability.mutable,
            origin: "Dispatch",
          )
          ..useInFrame(-1)
          ..useInFrame(frameCount);

    var startLabel = dispatchCopper.data.addLabel();
    var musicPtr = startLabel + 6;
    var framePtr = FreeLabel("framePtr");
    var dataPtr = FreeLabel("dataPtr");
    var dataStart = frameData.label + startFrame * 6;
    dispatchCopper.call(musicFrames[startFrame]);
    dispatchCopper.waitBlit();
    dispatchCopper.high(BLTBPTH, dataStart);
    dispatchCopper.low(BLTBPTL, dataStart, label: dataPtr);
    dispatchCopper <<
        (Blit()
          ..channelMask = enableB | enableC | enableD
          ..bStride = 0
          ..bShift = 11
          ..cPtr = ptrMask.label
          ..dPtr = musicPtr
          ..dStride = 4
          ..minterms = B & C
          ..height = 2);
    dispatchCopper <<
        (Blit()
          ..channelMask = enableB
          ..bStride = 2
          ..emitModulos = true);
    dispatchCopper <<
        (Blit()
          ..channelMask = enableB | enableC | enableD
          ..bStride = 0
          ..bShift = 11
          ..cPtr = ptrMask.label
          ..dPtr = framePtr
          ..dStride = 4
          ..minterms = B & C
          ..height = 2);
    dispatchCopper <<
        (Blit()
          ..channelMask = enableB
          ..bStride = 2
          ..emitModulos = true);
    dispatchCopper <<
        (Blit()
          ..channelMask = enableB | enableD
          ..dPtr = dataPtr
          ..minterms = B);
    dispatchCopper.high(COP1LCH, frames[startFrame].label, label: framePtr);
    dispatchCopper.low(COP1LCL, frames[startFrame].label);
    dispatchCopper.move(COPJMP1, 0);

    roots.add(dispatchCopper.data);

    initialCopper.finalizer = (c) => c.ptr(COP1LC, dispatchCopper.label);
    for (int i = 0; i < frames.length; i++) {
      frames[i].finalizer = (c) => c.ptr(COP1LC, dispatchCopper.label);
    }

    // Enable sprites, 320x180, borderblank
    initialCopper.move(DMACON, 0x8020);
    initialCopper.move(DIWSTRT, 0x5281);
    initialCopper.move(DIWSTOP, 0x06C1);
    initialCopper.move(BPLCON3, 0x0020);
    initialCopper >> Display();
  }

  void build({List<(String, String)>? categories}) {
    Memory m = Memory.fromRoots(
      0x20_0000,
      roots,
      frameCount: frames.length,
      loopFrame: loopFrame,
    );

    void p(String title) {
      print(
        sprintf("%-15s   %9d    %9d  %9d   %9d", [
          title,
          m.dataBlocks.where((b) => b.origin is Copper).length,
          m.dataBlocks.where((b) => b.origin is Copper).map((b) => b.size).sum,
          m.dataBlocks.map((b) => b.size).sum,
          m.spaceBlocks.map((b) => b.size).sum,
        ]),
      );
    }

    print("                Copperlists  Copper size  Data size  Space size");
    p("Initial");
    m.finalize();
    p("After finalize");
    var chipData = m.build();
    p("After dedup");
    File(outputFile).writeAsBytesSync(chipData);

    if (categories != null) {
      List<RegExp> patterns = categories.map((c) => RegExp(c.$2)).toList();
      List<int> sizes = List.filled(categories.length, 0);
      for (Data b in m.dataBlocks) {
        for (int i = 0; i < patterns.length; i++) {
          if (patterns[i].hasMatch(b.origin.toString())) {
            sizes[i] += b.size;
            break;
          }
        }
      }
      print("");
      int maxLength = categories.map((c) => c.$1.length).max;
      for (var (i, (name, _)) in categories.indexed) {
        print(
          sprintf("%-${maxLength}s %9d %7.1fk", [
            name,
            sizes[i],
            sizes[i] / 1024,
          ]),
        );
      }
    }

    print("");
    print("Final file size: ${chipData.length}");
  }
}

class MusicDemoBase extends DemoBase {
  final Music music;

  @override
  int getTimestamp(int position, int row) {
    return music.getTimestamp(position, row);
  }

  int musicFrame(Object f) {
    return switch (f) {
      (int p, int r) => getTimestamp(p, r),
      (int p, int r, int o) => getTimestamp(p, r) + o,
      _ => throw Exception("Invalid frame specifier: $f"),
    };
  }

  MusicDemoBase(this.music, {super.startFrame = 0})
    : super(music.frames.length, loopFrame: music.restart) {
    music.optimize();
  }

  MusicDemoBase.withProtrackerFile(String filename, {int startFrame = 0})
    : this(
        ProtrackerPlayer(ProtrackerModule.readFromFile(filename)).toMusic(),
        startFrame: startFrame,
      );

  @override
  CopperComponent getMusicFrame(int f) {
    return music.frames[f];
  }
}

extension FrameIndex on Copper {
  int get index {
    if (isPrimary && origin is int) {
      return origin as int;
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
