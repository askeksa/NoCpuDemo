import 'dart:collection';

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

  Color interpolate(Color other, double weight) {
    assert(weight >= 0 && weight <= 1, "Weight must be between 0 and 1");
    return Color.clamped(
      (r + (other.r - r) * weight).round(),
      (g + (other.g - g) * weight).round(),
      (b + (other.b - b) * weight).round(),
    );
  }

  int get upper =>
      ((rgb >> 12) & 0xF00) | ((rgb >> 8) & 0x0F0) | ((rgb >> 4) & 0x00F);
  int get lower => ((rgb >> 8) & 0xF00) | ((rgb >> 4) & 0x0F0) | (rgb & 0x00F);
}

class Palette implements CopperComponent {
  final SplayTreeMap<int, Color> colors;

  Palette(this.colors) {
    assert(() {
      for (final index in colors.keys) {
        if (index < 0 || index > 255) {
          return false;
        }
      }
      return true;
    }(), "Palette indices must be between 0 and 255");
  }

  Palette.empty() : this(SplayTreeMap<int, Color>());

  Palette.fromMap(Map<int, Color> map) : this(SplayTreeMap.from(map));

  factory Palette.rgb12(List<int> rgb12List, {int start = 0}) {
    final colors = SplayTreeMap<int, Color>();
    for (int i = 0; i < rgb12List.length; i++) {
      colors[start + i] = Color.rgb12(rgb12List[i]);
    }
    return Palette(colors);
  }

  factory Palette.rgb24(List<int> rgb24List, {int start = 0}) {
    final colors = SplayTreeMap<int, Color>();
    for (int i = 0; i < rgb24List.length; i++) {
      colors[start + i] = Color.rgb24(rgb24List[i]);
    }
    return Palette(colors);
  }

  factory Palette.generate(int count, (int, Color) Function(int) generator) {
    final colors = SplayTreeMap<int, Color>();
    for (int i = 0; i < count; i++) {
      var (index, color) = generator(i);
      colors[index] = color;
    }
    return Palette(colors);
  }

  factory Palette.generateRange(
    int start,
    int count,
    Color Function(int index) generator,
  ) {
    final colors = SplayTreeMap<int, Color>();
    for (int i = 0; i < count; i++) {
      colors[start + i] = generator(i);
    }
    return Palette(colors);
  }

  factory Palette.fromIlbm(IlbmImage ilbm) {
    final colorMap = ilbm.colorMapData;
    if (colorMap == null) {
      throw ArgumentError("ILBM data does not contain a color map");
    }
    return Palette.generateRange(0, colorMap.length ~/ 3, (i) {
      return Color.rgb8(
        colorMap[i * 3],
        colorMap[i * 3 + 1],
        colorMap[i * 3 + 2],
      );
    });
  }

  factory Palette.fromFile(String path) {
    return Palette.fromIlbm(IlbmImage.fromFile(path));
  }

  Palette shift(int delta) {
    final shiftedColors = SplayTreeMap<int, Color>();
    colors.forEach((index, color) {
      shiftedColors[index + delta] = color;
    });
    return Palette(shiftedColors);
  }

  Color operator [](int index) {
    if (colors.containsKey(index)) {
      return colors[index]!;
    }
    throw RangeError.index(index, this, "palette index", null, 256);
  }

  operator []=(int index, Color color) {
    if (index < 0 || index > 255) {
      throw RangeError.range(index, 0, 255, "palette index");
    }
    colors[index] = color;
  }

  Palette sub(int start, int end) {
    if (start < 0 || start > 255) {
      throw RangeError.range(start, 0, 255, "start");
    }
    if (end < 0 || end > 255) {
      throw RangeError.range(end, 0, 255, "end");
    }
    if (start > end) {
      throw ArgumentError("Start must be less than or equal to end");
    }

    final subColors = SplayTreeMap<int, Color>();
    for (int i = start; i <= end; i++) {
      if (colors.containsKey(i)) {
        subColors[i] = colors[i]!;
      }
    }
    return Palette(subColors);
  }

  Palette merge(Palette other) {
    final combined = SplayTreeMap<int, Color>.from(colors)
      ..addAll(other.colors);
    return Palette(combined);
  }

  Palette operator |(Palette other) => merge(other);

  Iterable<(int, Color)> get entries sync* {
    for (final entry in colors.entries) {
      yield (entry.key, entry.value);
    }
  }

  Palette interpolate(Palette other, double weight, {Color? defaultColor}) {
    assert(weight >= 0 && weight <= 1, "Weight must be between 0 and 1");
    final interpolatedColors = SplayTreeMap<int, Color>();
    for (final (index, color) in entries) {
      final otherColor =
          other.colors[index] ??
          defaultColor ??
          (throw ArgumentError(
            "Missing color at index $index and no default color provided",
          ));
      interpolatedColors[index] = color.interpolate(otherColor, weight);
    }
    return Palette(interpolatedColors);
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
