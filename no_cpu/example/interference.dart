import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:no_cpu/no_cpu.dart';
import 'package:sprintf/sprintf.dart';

import '../bin/base.dart' show outputFile, assetsPath;

main() {
  var noise1 = ChunkyPixels.fromFile("$assetsPath/bluenoise3.raw", 128, 128);
  var noise2 = ChunkyPixels.fromFile("$assetsPath/bluenoise1.raw", 128, 128);
  
  var bitmap1 = Bitmap.generate(
    320 * 2,
    180 * 2,
    (x, y) {
      int nx = x - 320;
      int ny = y - 180;
      double distance = sqrt(nx * nx + ny * ny) + 950;
      double color = (distance * distance / 165000) + 1000000;
      color -= color.floor();
      return _bluenoiseDither4(noise1, color, x, y);
    },
    depth: 4,
    interleaved: true,
    mutability: Mutability.mutable,
  );

  var bitmap2 = Bitmap.generate(
    320 * 2,
    180 * 2,
    (x, y) {
      int nx = x - 320;
      int ny = y - 180;
      double distance = sqrt(nx * nx + ny * ny);
      var color = 500.0 / (distance + 130.0);
      color -= color.floor();
      return _bluenoiseDither3(noise2, color, x, y);
    },
    depth: 3,
    interleaved: true,
    mutability: Mutability.mutable
  );

  var palette = Palette.generateRange(0, 256, (i) {
    int evenColor =
        ((i & 0x40) >> 3) | ((i & 0x10) >> 2) | ((i & 0x04) >> 1) | (i & 0x01);
    int oddColor =
        ((i & 0x20) >> 3) |
        ((i & 0x08) >> 2) |
        ((i & 0x02) >> 1);

    var colorF = (((oddColor << 1) + evenColor) & 15) / 16.0;
    return Color.rgb8((sin(colorF * pi * 2) * 45 + 64).toInt(),
        (sin(colorF * pi * 2 + pi / 3) * 63 + 64).toInt(),
        (sin(colorF * pi * 2 + pi * 2 / 3) * 32 + 45).toInt());
  });

  var paletteIndices = List<int>.generate(128, (i) => i).shuffled();

  final fadeSteps = 39;
  final fadeSpeed = 3;
  assert(fadeSteps % fadeSpeed == 0, "fadeSteps must be a multiple of fadeSpeed");

  List<Copper> frames = List.generate(
    2000,
    (i) => Copper(isPrimary: true, origin: i)
      ..useInFrame(i)
      ..mutability = Mutability.mutable,
  );
  for (var (i, frame) in frames.indexed) {
    var evenXf = (sin(i / 102 + 4.5) + sin(i / 133)) / 2;
    var evenYf = (sin(i / 160 + 0.3) + sin(i / 131)) / 2;
    var evenX = (evenXf * 160 * 4 + 160 * 4).toInt();
    var evenY = (evenYf * 90 + 90).toInt();

    var oddXf = (sin(i / 175 + 0.2) + sin(i / 163)) / 2;
    var oddYf = (sin(i / 130 + 2.35) + sin(i / 127)) / 2;
    var oddX = (oddXf * 160 * 4 + 160 * 4).toInt();
    var oddY = (oddYf * 90 + 90).toInt();

    bool flip = i & 1 == 0;

    var display = Display()
      ..oddHorizontalScroll = oddX
      ..oddVerticalScroll = oddY
      ..oddFlip = flip
      ..evenHorizontalScroll = evenX
      ..evenVerticalScroll = evenY
      ..evenFlip = flip;

    var newPalette = Palette.empty();
    var lastIndex = i * fadeSpeed;
    for (int j = 0; j <= fadeSteps; j++) {
      var fadeIndex = lastIndex - j;
      for (int fullIndex = fadeIndex - fadeSpeed; fullIndex < fadeIndex; fullIndex++) {
        if (fullIndex > 0 && fullIndex < paletteIndices.length) {
          newPalette[paletteIndices[fullIndex]] = palette[paletteIndices[fullIndex]];
        }
      }
      if (fadeIndex >= 0 && fadeIndex < paletteIndices.length) {
        int index = paletteIndices[fadeIndex];
        var color = Color.rgb24(0).interpolate(palette[index], j / fadeSteps);
        newPalette[index] = color;
      }
    }

    frame >> newPalette;

    display.setBitmaps(bitmap1, bitmap2);

    frame >> display;

    frame.ptr(COP1LC, frames[(i + 1) % frames.length].label);
  }

  Copper initialCopper = Copper(isPrimary: true, origin: "Initial")
    ..data.address = 0x00_0000
    ..useInFrame(-1);
  initialCopper.move(DMACON, 0x8020);
  initialCopper.move(DIWSTRT, 0x5281);
  initialCopper.move(DIWSTOP, 0x06C1);
  initialCopper.move(BPLCON3, 0x0000);
  initialCopper >> Palette.generateRange(0, 256, (_) => Color.rgb24(0));
  initialCopper.ptr(COP1LC, frames[0].label);

  Memory m = Memory.fromRoots(0x20_0000, [initialCopper.data]);
  
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
}

int _bluenoiseDither3(ChunkyPixels noise, double colour, int x, int y) {
  int ncolour = (colour * 8 * 16).toInt();
  int n = ncolour >> 4;
  int frac = ncolour & 0xF;

  return (frac >= noise.getPixel(x % noise.width, y % noise.height) & 0xF ? n + 1 : n).toInt() & 7;
}

int _bluenoiseDither4(ChunkyPixels noise, double colour, int x, int y) {
  int ncolour = (colour * 16 * 16).toInt();
  int n = ncolour >> 4;
  int frac = ncolour & 0xF;

  return (frac >= noise.getPixel(x % noise.width, y % noise.height) & 0xF ? n + 1 : n).toInt() & 15;
}
