import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../base.dart' show assetsPath;

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

  late final Bitmap bitmap1 = _generateBitmap(4, 320, 180, (int x, int y) {
    double distance = sqrt(x * x + y * y) + 950;
    double color = (distance * distance / 165000) + 1000000;
    return _bluenoiseDither4(_noise1, color - color.floor(), x, y);
  });

  late final Bitmap bitmap2 = _generateBitmap(3, 320, 180, (int x, int y) {
    double distance = sqrt(x * x + y * y);
    var color = 500.0 / (distance + 130.0);
    return _bluenoiseDither3(_noise2, color - color.floor(), x, y);
  });

  static int _bluenoiseDither(
    ChunkyPixels noise,
    double fcolour,
    int x,
    int y,
    int totalColors,
  ) {
    int threshold = noise.getPixel(x % noise.width, y % noise.height) & 0xF;
    int ncolour = (fcolour * totalColors * 16).toInt();
    int n = ncolour >> 4;
    int frac = ncolour & 0xF;

    return (frac >= threshold ? n + 1 : n) % totalColors;
  }

  static int _bluenoiseDither3(
    ChunkyPixels noise,
    double colour,
    int x,
    int y,
  ) => _bluenoiseDither(noise, colour, x, y, 8);

  static int _bluenoiseDither4(
    ChunkyPixels noise,
    double colour,
    int x,
    int y,
  ) => _bluenoiseDither(noise, colour, x, y, 16);

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

  InterferenceFrame frame(
    double evenX,
    double evenY,
    double oddX,
    double oddY,
    bool flip,
  ) {
    return InterferenceFrame(this, evenX, evenY, oddX, oddY, flip);
  }
}

class InterferenceFrame implements CopperComponent {
  final Interference interference;
  final double _evenXf;
  final double _evenYf;
  final double _oddXf;
  final double _oddYf;
  final bool _flip;

  late final display = _scrollDisplay()
    ..setBitmaps(interference.bitmap1, interference.bitmap2);

  Display _scrollDisplay() {
    var evenX = (_evenXf * 160 * 4 + 160 * 4).toInt();
    var evenY = (_evenYf * 90 + 90).toInt();

    var oddX = (_oddXf * 160 * 4 + 160 * 4).toInt();
    var oddY = (_oddYf * 90 + 90).toInt();

    var display = Display()
      ..alignment = 1
      ..oddHorizontalScroll = oddX
      ..oddVerticalScroll = oddY
      ..oddFlip = _flip
      ..evenHorizontalScroll = evenX
      ..evenVerticalScroll = evenY
      ..evenFlip = _flip;

    return display;
  }

  InterferenceFrame(
    this.interference,
    this._evenXf,
    this._evenYf,
    this._oddXf,
    this._oddYf,
    this._flip,
  );

  @override
  void addToCopper(Copper copper) {
    copper >> display;
  }
}
