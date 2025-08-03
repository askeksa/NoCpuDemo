
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:no_cpu/color.dart';
import 'package:no_cpu/copper.dart';

import '../bin/base.dart';
import '../bin/effects/interference.dart';

main() {
  InterferenceTest().build();
}

class InterferenceTest extends DemoBase {
  Interference interference = Interference();

  // Generate a palette suitable for the interference effect.
  // The generator function should return a Color object for each color index up to and including the maximum index
  static Palette _generatePalette(Color Function(int index, int maxIndex) generator) {
    var colors = List.generate(16, (i) => generator(i, 15));

    return Palette.generateRange(0, 256, (i) {
      int evenColor =
          ((i & 0x40) >> 3) | ((i & 0x10) >> 2) | ((i & 0x04) >> 1) | (i & 0x01);
      int oddColor =
          ((i & 0x20) >> 3) |
          ((i & 0x08) >> 2) |
          ((i & 0x02) >> 1);

      return colors[((oddColor << 1) + evenColor) & 15];
    });
  }

  final _blackPalette = Palette.generateRange(0, 256, (i) => Color.rgb24(0));

  final _paletteIndices = List<int>.generate(128, (i) => i).shuffled();

  final _palette1 = _generatePalette((i, maxIndex) {
    var colorF = i / (maxIndex + 1);
    return Color.rgb8((sin(colorF * pi * 2) * 45 + 64).toInt(),
        (sin(colorF * pi * 2 + pi / 3) * 63 + 64).toInt(),
        (sin(colorF * pi * 2 + pi * 2 / 3) * 32 + 45).toInt());
  });

  final _palette2 = _generatePalette((i, maxIndex) {
    var colorF = i / (maxIndex + 1);
    return Color.rgb8(
        (sin(colorF * pi * 2 + pi / 3) * 63 + 64).toInt(),
        (sin(colorF * pi * 2 + 1.0) * 45 + 64).toInt(),
        (sin(colorF * pi * 2 + pi * 2 / 3  + 0.5) * 32 + 45).toInt());
  });

  Palette _randomPartialFade(int frame, Palette srcPalette, Palette destPalette) {
    final fadeSteps = 39; // how many frames fading one color takes
    final fadeSpeed = 3;  // 
    assert(fadeSteps % fadeSpeed == 0, "fadeSteps must be a multiple of fadeSpeed");

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
        var color = srcPalette[paletteIndex].interpolate(destPalette[paletteIndex], step / fadeSteps);
        newPalette[paletteIndex] = color;
      }
    }

    return newPalette;
  }

  InterferenceTest() : super(500, loopFrame: 0) {
    F(0, 0) - 499 | (int i, Copper f) {
      if (i == 0) {
        f << _blackPalette;
      }
      
      f << interference.frame(i);
      var newPalette = _randomPartialFade(i, _blackPalette, _palette1);
      f << newPalette;
    };

  }
}
