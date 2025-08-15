import 'dart:math';

import 'package:collection/collection.dart';
import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart';
import '../bin/effects/interference.dart';

main() {
  InterferenceTest().build();
}

class InterferenceTest extends DemoBase {
  static final int _variant = 1; // 0 or 1

  static final Interference interference = Interference(_variant);

  final _paletteIndices = List<int>.generate(
    128,
    (i) => i,
  ).shuffled(Random(1337));

  // ignore: unused_field
  final _palette1 = interference.generatePalette((i, maxIndex) {
    var colorF = i / (maxIndex + 1);
    return Color.rgb8(
      (sin(colorF * pi * 2) * 45 + 64).toInt(),
      (sin(colorF * pi * 2 + pi / 3) * 63 + 64).toInt(),
      (sin(colorF * pi * 2 + pi * 2 / 3) * 32 + 45).toInt(),
    );
  });

  // ignore: unused_field
  final _palette2 = interference.generatePalette((i, maxIndex) {
    var colorF = i / (maxIndex + 1);
    return Color.rgb8(
      (sin(colorF * pi * 2 + pi / 3) * 63 + 64).toInt(),
      (sin(colorF * pi * 2 + 1.0) * 45 + 64).toInt(),
      (sin(colorF * pi * 2 + pi * 2 / 3 + 0.5) * 32 + 45).toInt(),
    );
  });

  // ignore: unused_field
  final _palette3 = interference.generatePalette((i, maxIndex) {
    var colorF = i / (maxIndex + 1);
    return Color.rgb8(
      (sin(colorF * pi * 2 + pi / 3) * 20 + 74).toInt(),
      (sin(colorF * pi * 2 + 1.0) * 20 + 34).toInt(),
      (sin(colorF * pi * 2 + pi * 2 / 3 + 0.5) * 12 + 25).toInt(),
    );
  });

  // ignore: unused_field
  final _palette4 = interference.generatePalette((i, maxIndex) {
    var colorF = i / (maxIndex + 1);
    return Color.rgb8(
      (sin(colorF * pi * 2 + 1.0) * 20 + 44).toInt(),
      (sin(colorF * pi * 3 + pi / 3) * 10 + 24).toInt(),
      (sin(colorF * pi * 2 + pi * 2.5 / 3 + 0.5) * 12 + 35).toInt(),
    );
  });

  late final _openingPalette = interference.generatePalette((i, max) {
    double f = i / (max + 1);
    double component(double f) => sin(f * 2 * pi) * 0.5 + 0.5;
    return Color.hsl(
      component(f) * 0.17 + 0.7,
      component(f) * 0.2 + 0.3,
      component(f * 2) * 0.15 + 0.1,
    );
  });

  // ignore: unused_field
  final _grayscalePalette = interference.generatePalette(
    (i, maxIndex) => Color.rgb8(
      i * 0xFF ~/ maxIndex,
      i * 0xFF ~/ maxIndex,
      i * 0xFF ~/ maxIndex,
    ),
  );

  final _blackPalette = Palette.generateRange(0, 256, (i) => Color.rgb24(0));

  static final _fireColorList = Interference.shuffleColorList([
    Color.rgb8(101, 0, 0),
    Color.rgb8(136, 14, 0),
    Color.rgb8(110, 29, 0),
    Color.rgb8(145, 50, 0),
    Color.rgb8(183, 75, 0),
    Color.rgb8(52, 12, 0),
    Color.rgb8(255, 126, 0),
    Color.rgb8(46, 0, 0),
    Color.rgb8(255, 191, 0),
    Color.rgb8(75, 23, 0),
    Color.rgb8(255, 246, 130),
    Color.rgb8(110, 6, 0),
    Color.rgb8(255, 255, 241),
    Color.rgb8(165, 0, 0),
    Color.rgb8(237, 113, 0),
    Color.rgb8(255, 67, 0),
  ]);

  final _blueOrangeColorList = Interference.shuffleColorList([
    Color.rgb8(6, 7, 52),
    Color.rgb8(6, 15, 65),
    Color.rgb8(6, 27, 77),
    Color.rgb8(5, 44, 90),
    Color.rgb8(4, 63, 103),
    Color.rgb8(52, 78, 128),
    Color.rgb8(0, 113, 128),
    Color.rgb8(110, 64, 75),
    Color.rgb8(0, 155, 176),
    Color.rgb8(159, 70, 0),
    Color.rgb8(0, 213, 219),
    Color.rgb8(191, 67, 0),
    Color.rgb8(214, 200, 177),
    Color.rgb8(255, 72, 0),
    Color.rgb8(255, 142, 24),
    Color.rgb8(214, 99, 0),
  ]);

  final _blueColorList = Interference.shuffleColorList([
    Color.rgb8(0, 17, 41),
    Color.rgb8(29, 22, 52),
    Color.rgb8(27, 16, 52),
    Color.rgb8(26, 10, 38),
    Color.rgb8(23, 29, 49),
    Color.rgb8(29, 32, 80),
    Color.rgb8(8, 49, 55),
    Color.rgb8(41, 51, 90),
    Color.rgb8(13, 81, 81),
    Color.rgb8(23, 47, 55),
    Color.rgb8(54, 119, 105),
    Color.rgb8(71, 67, 93),
    Color.rgb8(23, 99, 125),
    Color.rgb8(92, 77, 173),
    Color.rgb8(113, 99, 183),
    Color.rgb8(40, 60, 113),
  ]);

  List<Color> dimColors(List<Color> colors, double lightness) =>
      colors.map((c) => Color.black.interpolate(c, lightness)).toList();

  // ignore: unused_field
  late final _firePalette = interference.generatePaletteFromList(
    dimColors(_fireColorList, 0.5),
  );

  // ignore: unused_field
  late final _blueOrangePalette = interference.generatePaletteFromList(
    dimColors(_blueOrangeColorList, 0.5),
  );

  // ignore: unused_field
  late final _bluePalette = interference.generatePaletteFromList(
    _blueColorList,
  );

  Palette _randomPartialFade(
    int frame,
    Palette srcPalette,
    Palette destPalette,
  ) {
    final fadeSteps = 39; // how many frames fading one color takes
    final fadeSpeed = 3; //
    assert(
      fadeSteps % fadeSpeed == 0,
      "fadeSteps must be a multiple of fadeSpeed",
    );

    var newPalette = Palette.empty();
    var lastIndex = frame * fadeSpeed;
    var firstIndex = lastIndex - fadeSteps;

    for (int i = 0; i < fadeSpeed; i++) {
      int index = firstIndex - fadeSpeed + i;
      if (index > 0 && index < _paletteIndices.length) {
        int paletteIndex = _paletteIndices[index];
        newPalette[paletteIndex] = destPalette[paletteIndex];
      }
    }

    // Fade [fadeSteps] colors before [lastIndex]
    for (int step = 0; step <= fadeSteps; step++) {
      var index = lastIndex - step;

      if (index >= 0 && index < _paletteIndices.length) {
        int paletteIndex = _paletteIndices[index];
        var color = srcPalette[paletteIndex].interpolate(
          destPalette[paletteIndex],
          step / fadeSteps,
        );
        newPalette[paletteIndex] = color;
      }
    }

    return newPalette;
  }

  InterferenceTest() : super(1500, loopFrame: 0) {
    F(0, 0) - 1499 |
        (int frame, Copper f) {
          if (frame == 0) {
            f << _blackPalette;
          }

          f <<
              interference.frame(
                (sin(frame / 102 + 1.4) + sin(frame / 133)) / 2, // even X
                (sin(frame / 160 + 0.3) + sin(frame / 131)) / 2, // even Y
                (sin(frame / 175 + 0.2) + sin(frame / 163)) / 2, // odd X
                (sin(frame / 130 + 1.40) + sin(frame / 127)) / 2, // odd Y
                frame & 1 != 0, // flip
              );
          var newPalette = _randomPartialFade(frame, _blackPalette, _palette4);
          f << newPalette;
        };
  }
}
