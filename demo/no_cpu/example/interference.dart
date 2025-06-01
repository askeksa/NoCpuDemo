import 'dart:io';
import 'dart:math';

import 'package:no_cpu/no_cpu.dart';
import 'package:path/path.dart' show dirname;

String scriptPath = dirname(Platform.script.toFilePath());
String runnerPath = "$scriptPath/../../../runner";
String outputFile = "$runnerPath/chip.dat";

main() {
  var bitmap1 = Bitmap.generate(
    320 * 2,
    180 * 2,
    (x, y) {
      int nx = x - 320;
      int ny = y - 180;
      double distance = sqrt(nx * nx + ny * ny) + 950;
      return _orderedDither4x4((distance * distance / 65000) + 1000000, x, y);
    },
    depth: 4,
    interleaved: true,
  );
  print(bitmap1);

  var bitmap2 = Bitmap.generate(
    320 * 2,
    180 * 2,
    (x, y) {
      int nx = x - 320;
      int ny = y - 180;
      var distance = sqrt(nx * nx + ny * ny);
      return _orderedDither4x4(1500 / (distance + 130), x, y);
    },
    depth: 4,
    interleaved: true,
  );

  var bitmap3 = Bitmap.generate(
    320 * 2,
    180 * 2,
    (x, y) {
      int nx = x - 320;
      int ny = y - 180;
      if (y == 0) y = 1;
      return _orderedDither4x4((sin(nx / 10) + cos(ny / 10)) * 0.5, x, y);
    },
    depth: 4,
    interleaved: true,
  );
  print(bitmap2);

  Copper sub = Copper(origin: "Subroutine");

  List<Copper> frames = List.generate(
    800,
    (i) => Copper(isPrimary: true, origin: i)
      ..useInFrame(i)
      ..mutability = Mutability.mutable,
  );
  for (var (i, frame) in frames.indexed) {
    var evenXf = (sin(i / 50) + sin(i / 33)) / 2;
    var evenYf = (sin(i / 80) + sin(i / 33)) / 2;
    var evenX = (evenXf * 160 * 4 + 160 * 4).toInt();
    var evenY = (evenYf * 90 + 90).toInt();

    var oddXf = (sin(i / 75) + sin(i / 63)) / 2;
    var oddYf = (sin(i / 30) + sin(i / 27)) / 2;
    var oddX = (oddXf * 160 * 4 + 160 * 4).toInt();
    var oddY = (oddYf * 90 + 90).toInt();

    var display = Display()
      ..oddHorizontalScroll = oddX
      ..oddVerticalScroll = oddY
      ..evenHorizontalScroll = evenX
      ..evenVerticalScroll = evenY;

    if (i < 200) {
      display.setBitmaps(bitmap3, bitmap3);
    } else if (i < 400) {
      display.setBitmaps(bitmap2, bitmap2);
    } else if (i < 600) {
      display.setBitmaps(bitmap2, bitmap3);
    } else {
      display.setBitmaps(bitmap1, bitmap2);
    }

    frame >> display;

    frame.call(sub);
    frame.ptr(COP1LC, frames[(i + 1) % frames.length].label);
  }

  var palette = Palette.generateRange(0, 256, (i) {
    int evenColor =
        ((i & 0x40) >> 3) | ((i & 0x10) >> 2) | ((i & 0x04) >> 1) | (i & 0x01);
    int oddColor =
        ((i & 0x80) >> 4) |
        ((i & 0x20) >> 3) |
        ((i & 0x08) >> 2) |
        ((i & 0x02) >> 1);
    var index = (evenColor + oddColor) & 0x0F;

    int color = (sin(index / 15 * pi) * 15.5).toInt();

    return Color.rgb8(color * 8 + 50, color * 0x11, color * 5 + 120);
  });

  Copper initialCopper = Copper(isPrimary: true, origin: "Initial")
    ..data.address = 0x00_0000
    ..useInFrame(-1);
  initialCopper.move(DMACON, 0x8020);
  initialCopper.move(DIWSTRT, 0x5281);
  initialCopper.move(DIWSTOP, 0x06C1);
  initialCopper << palette;
  initialCopper.move(BPLCON3, 0x0000);
  initialCopper.ptr(COP1LC, frames[0].label);

  Memory m = Memory.fromRoots(0x20_0000, [initialCopper.data]);
  File(outputFile).writeAsBytesSync(m.build());
}

var _ditherMatrix = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

int _orderedDither4x4(double colour, int x, int y) {
  int ncolour = ((colour * 14 + 0.5) * 16).toInt();
  int n = ncolour >> 4;
  int frac = ncolour & 0xF;

  return frac >= _ditherMatrix[x & 0x3][y & 0x3] ? n + 1 : n;
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
