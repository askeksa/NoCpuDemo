import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../base.dart' show assetsPath;

class Interference {
  static final ChunkyPixels _noise1 = ChunkyPixels.fromFile(
    "$assetsPath/bluenoise3.raw",
    128,
    128,
  );
  static final ChunkyPixels _noise2 = ChunkyPixels.fromFile(
    "$assetsPath/bluenoise1.raw",
    128,
    128,
  );

  static final int _bitmapWidth = 320 - 48;
  static final int _bitmapHeight = 180 - 32;

  late final int _variant;

  final bitmapVariants = [
    (Interference.bitmap1, Interference.bitmap2),
    (Interference.bitmap2, Interference.bitmap2),
    (Interference.bitmap2, Interference.bitmap3),
    (Interference.bitmap1, Interference.bitmap3),
  ];

  Bitmap get effectBitmap1 => bitmapVariants[_variant].$1;
  Bitmap get effectBitmap2 => bitmapVariants[_variant].$2;

  int get totalColors => 1 << max(effectBitmap1.depth, effectBitmap2.depth);

  // Generate a palette suitable for the interference effect.
  // The generator function should return a Color object for each color index up to and including the maximum index
  Palette generatePalette(Color Function(int index, int maxIndex) generator) {
    var colors = List.generate(
      totalColors,
      (i) => generator(i, totalColors - 1),
    );

    return Palette.generateRange(0, 256, (i) {
      int evenColor =
          ((i & 0x40) >> 3) |
          ((i & 0x10) >> 2) |
          ((i & 0x04) >> 1) |
          (i & 0x01);
      int oddColor = ((i & 0x20) >> 3) | ((i & 0x08) >> 2) | ((i & 0x02) >> 1);

      if (totalColors == 8) {
        evenColor &= 7;
      } else {
        oddColor <<= 1;
      }
      return colors[(oddColor + evenColor) % totalColors];
    });
  }

  Palette generatePaletteFromList(List<Color> palette) {
    assert(palette.length == 16);
    return generatePalette(
      (index, _) => palette[totalColors == 8 ? index * 2 : index],
    );
  }

  static List<Color> shuffleColorList(List<Color> palette) {
    assert(palette.length == 16);
    return List.generate(16, (index) {
      if (index <= 7) {
        return palette[index << 1];
      } else {
        return palette[31 - (index << 1)];
      }
    });
  }

  static final Bitmap bitmap1 = _generateBitmap(
    4,
    _bitmapWidth,
    _bitmapHeight,
    (int x, int y) {
      double distance = sqrt(x * x + y * y) + 950;
      double color = (distance * distance / 165000) + 1000000;
      return _bluenoiseDither4(_noise1, color - color.floor(), x, y);
    },
  );

  static final Bitmap bitmap2 = _generateBitmap(
    3,
    _bitmapWidth,
    _bitmapHeight,
    (int x, int y) {
      double distance = sqrt(x * x + y * y);
      var color = 500.0 / (distance + 130.0);
      return _bluenoiseDither3(_noise2, color - color.floor(), x, y);
    },
  );

  static final Bitmap bitmap3 = _generateBitmap(
    3,
    _bitmapWidth,
    _bitmapHeight,
    (int x, int y) {
      double distance1 = sqrt((x - 80) * (x - 80) + y * y) + 950;
      double color1 = (distance1 * distance1 / 165000) + 1000000;
      double distance2 = sqrt((x + 80) * (x + 80) + y * y);
      double color2 = 500.0 / (distance2 + 130.0);
      double color = (color1 + color2) / 2;
      return _bluenoiseDither3(_noise2, color - color.floor(), x, y);
    },
  );

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
      w + 320,
      h + 180,
      (x, y) {
        int nx = x - (160 + w ~/ 2);
        int ny = y - (90 + h ~/ 2);
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
    return InterferenceFrame(this, evenX, evenY, oddX, oddY, flip, _variant);
  }

  Interference(this._variant);
}

class InterferenceFrame implements CopperComponent {
  final Interference interference;
  final double _evenXf;
  final double _evenYf;
  final double _oddXf;
  final double _oddYf;
  final bool _flip;
  final int _variant;

  late final display = _scrollDisplay()
    ..setBitmaps(interference.effectBitmap1, interference.effectBitmap2);

  Display _scrollDisplay() {
    var xRange = (Interference.bitmap1.width - 320) ~/ 2;
    var yRange = (Interference.bitmap1.height - 180) ~/ 2;

    var xOffset = xRange;
    var yOffset = yRange;

    var evenX = (_evenXf * xRange * 4 + xOffset * 4).toInt();
    var evenY = (_evenYf * yRange + yOffset).toInt();

    var oddX = (_oddXf * xRange * 4 + xOffset * 4).toInt();
    var oddY = (_oddYf * yRange + yOffset).toInt();

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
    this._variant,
  );

  @override
  void addToCopper(Copper copper) {
    copper >> display;
  }
}
