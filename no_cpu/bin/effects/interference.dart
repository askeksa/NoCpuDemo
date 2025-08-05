import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show Uint8List;

import 'package:collection/collection.dart';
import 'package:no_cpu/no_cpu.dart';
import 'package:sprintf/sprintf.dart';

import '../base.dart' show outputFile, assetsPath;

class Interference {
  final ChunkyPixels _noise1 = ChunkyPixels.fromFile(
    "$assetsPath/bluenoise3.raw",
    128,
    128,
  );
  final ChunkyPixels _noise2 = ChunkyPixels.fromFile(
    "$assetsPath/bluenoise1.raw",
    128,
    128,
  );

  late final Bitmap _bitmap1 = _generateBitmap(4, 320, 180, (int x, int y) {
    double distance = sqrt(x * x + y * y) + 950;
    double color = (distance * distance / 165000) + 1000000;
    return _bluenoiseDither4(_noise1, color - color.floor(), x, y);
  });

  late final Bitmap _bitmap2 = _generateBitmap(3, 320, 180, (int x, int y) {
    double distance = sqrt(x * x + y * y);
    var color = 500.0 / (distance + 130.0);
    return _bluenoiseDither3(_noise2, color - color.floor(), x, y);
  });

  static int _bluenoiseDither3(
    ChunkyPixels noise,
    double colour,
    int x,
    int y,
  ) {
    int ncolour = (colour * 8 * 16).toInt();
    int n = ncolour >> 4;
    int frac = ncolour & 0xF;

    return (frac >= noise.getPixel(x % noise.width, y % noise.height) & 0xF
                ? n + 1
                : n)
            .toInt() &
        7;
  }

  static int _bluenoiseDither4(
    ChunkyPixels noise,
    double colour,
    int x,
    int y,
  ) {
    int ncolour = (colour * 16 * 16).toInt();
    int n = ncolour >> 4;
    int frac = ncolour & 0xF;

    return (frac >= noise.getPixel(x % noise.width, y % noise.height) & 0xF
                ? n + 1
                : n)
            .toInt() &
        15;
  }

  static Bitmap _generateBitmap(
    int planes,
    int w,
    int h,
    int Function(int x, int y) generator,
  ) {
    return Bitmap.generate(
      w * 2,
      h * 2,
      (x, y) {
        int nx = x - w;
        int ny = y - h;
        return generator(nx, ny);
      },
      depth: planes,
      interleaved: true,
      mutability: Mutability.mutable,
    );
  }

  InterferenceFrame frame(int frame) {
    return InterferenceFrame(this, frame);
  }
}

class InterferenceFrame implements CopperComponent {
  final Interference interference;
  final int frame;

  Display _scrollDisplay(int frame) {
    var evenXf = (sin(frame / 102 + 4.5) + sin(frame / 133)) / 2;
    var evenYf = (sin(frame / 160 + 0.3) + sin(frame / 131)) / 2;
    var evenX = (evenXf * 160 * 4 + 160 * 4).toInt();
    var evenY = (evenYf * 90 + 90).toInt();

    var oddXf = (sin(frame / 175 + 0.2) + sin(frame / 163)) / 2;
    var oddYf = (sin(frame / 130 + 2.35) + sin(frame / 127)) / 2;
    var oddX = (oddXf * 160 * 4 + 160 * 4).toInt();
    var oddY = (oddYf * 90 + 90).toInt();

    bool flip = frame & 1 == 0;

    return Display()
      ..oddHorizontalScroll = oddX
      ..oddVerticalScroll = oddY
      ..oddFlip = flip
      ..evenHorizontalScroll = evenX
      ..evenVerticalScroll = evenY
      ..evenFlip = flip;
  }

  InterferenceFrame(this.interference, this.frame);

  @override
  void addToCopper(Copper copper) {
    var display = _scrollDisplay(frame)
      ..setBitmaps(interference._bitmap1, interference._bitmap2);
    copper >> display;
  }
}
