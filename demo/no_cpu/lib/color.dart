import 'copper.dart';
import 'custom.dart';
import 'iff.dart';

/// Global border blanking flag.
bool borderBlank = true;

extension type Color(int rgb) {
  int get r => (rgb >> 16) & 0xFF;
  int get g => (rgb >> 8) & 0xFF;
  int get b => rgb & 0xFF;

  factory Color.rgb8(int r, int g, int b) {
    assert(r >= 0 && r <= 255, "Red must be between 0 and 255");
    assert(g >= 0 && g <= 255, "Green must be between 0 and 255");
    assert(b >= 0 && b <= 255, "Blue must be between 0 and 255");
    return Color((r << 16) | (g << 8) | b);
  }

  factory Color.clamped(int r, int g, int b) {
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);
    return Color((r << 16) | (g << 8) | b);
  }

  factory Color.rgb12(int value) {
    assert(
      value >= 0 && value <= 0xFFF,
      "RGB12 value must be between 0 and 0xFFF",
    );
    final r = ((value >> 8) & 0xF) * 17;
    final g = ((value >> 4) & 0xF) * 17;
    final b = (value & 0xF) * 17;
    return Color((r << 16) | (g << 8) | b);
  }

  factory Color.rgb24(int value) {
    assert(
      value >= 0 && value <= 0xFFFFFF,
      "RGB24 value must be between 0 and 0xFFFFFF",
    );
    return Color(value);
  }

  Color operator *(double factor) {
    return Color.clamped(
      (r * factor).round(),
      (g * factor).round(),
      (b * factor).round(),
    );
  }

  Color operator +(Color other) {
    return Color.clamped(r + other.r, g + other.g, b + other.b);
  }

  int get upper =>
      ((rgb >> 12) & 0xF00) | ((rgb >> 8) & 0x0F0) | ((rgb >> 4) & 0x00F);
  int get lower => ((rgb >> 8) & 0xF00) | ((rgb >> 4) & 0x0F0) | (rgb & 0x00F);
}

class PaletteRange {
  final int start;
  final List<Color> colors;

  PaletteRange(this.start, this.colors) {
    assert(start >= 0, "Palette range start must be non-negative");
    assert(
      start + colors.length <= 256,
      "Palette range must not exceed index 255",
    );
  }

  factory PaletteRange.generate(
    int start,
    int count,
    Color Function(int index) generator,
  ) {
    return PaletteRange(
      start,
      List<Color>.generate(count, (index) => generator(index)),
    );
  }

  PaletteRange shift(int delta) =>
      PaletteRange(start + delta, List<Color>.from(colors));

  int get length => colors.length;
}

class Palette implements CopperComponent {
  final List<PaletteRange> ranges;

  Palette(this.ranges) {
    assert(() {
      for (int i = 0; i < ranges.length - 1; i++) {
        if (ranges[i].start >= ranges[i + 1].start) {
          return false; // Ranges must be in order of increasing start index
        }
        if (ranges[i].start + ranges[i].length > ranges[i + 1].start) {
          return false; // Ranges must not overlap
        }
      }
      return true;
    }(), "Palette ranges must be in order and must not overlap");
  }

  factory Palette.generateRange(
    int start,
    int count,
    Color Function(int index) generator,
  ) {
    return Palette([PaletteRange.generate(start, count, generator)]);
  }

  factory Palette.fromIlbm(IlbmImage ilbm) {
    final colorMap = ilbm.colorMapData;
    if (colorMap == null) {
      throw ArgumentError("ILBM data does not contain a color map");
    }
    return Palette.generateRange(
      0,
      colorMap.length ~/ 3,
      (i) =>
          Color.rgb8(colorMap[i * 3], colorMap[i * 3 + 1], colorMap[i * 3 + 2]),
    );
  }

  Palette shift(int delta) {
    return Palette(ranges.map((range) => range.shift(delta)).toList());
  }

  Color operator [](int index) {
    for (final range in ranges) {
      if (index >= range.start && index < range.start + range.length) {
        return range.colors[index - range.start];
      }
    }
    throw RangeError.index(index, this, "palette index", null, ranges.length);
  }

  Palette merge(Palette other) {
    final combined = List<PaletteRange>.from(ranges)..addAll(other.ranges);
    combined.sort((a, b) => a.start.compareTo(b.start));
    return Palette(combined);
  }

  Palette operator |(Palette other) => merge(other);

  Iterable<(int, Color)> get entries sync* {
    for (final range in ranges) {
      for (int i = 0; i < range.length; i++) {
        yield (range.start + i, range.colors[i]);
      }
    }
  }

  @override
  void addToCopper(Copper copper) {
    // 8 blocks of 32 colors
    List<List<(int, int)>> upper = List.generate(8, (_) => []);
    List<List<(int, int)>> lower = List.generate(8, (_) => []);
    for (final (index, color) in entries) {
      int block = index >> 5;
      int offset = index & 0x1F;
      upper[block].add((offset, color.upper));
      if (color.lower != color.upper) lower[block].add((offset, color.lower));
    }

    int borderBlankFlag = borderBlank ? 0x0020 : 0x0000;
    for (int bank = 0; bank < 8; bank++) {
      int upperControl = (bank << 13) | 0x0000 | borderBlankFlag;
      int lowerControl = (bank << 13) | 0x0200 | borderBlankFlag;
      for (final (colors, control) in [
        (upper[bank], upperControl),
        (lower[bank], lowerControl),
      ]) {
        if (colors.isEmpty) continue;
        copper.move(BPLCON3, control);
        for (final (offset, color) in colors) {
          copper.move(COLORx[offset], color);
        }
      }
    }
  }
}
