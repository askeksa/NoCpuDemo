import 'dart:math';

import 'package:collection/collection.dart';
import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/transition.dart';
import '../effects/interference.dart';

mixin Text on NoCpuDemoBase {
  Transition waveTrans = Transition.generate(320, 180, (x, y) {
    return 20 +
        x * (0.2 + y * 0.001) -
        y * 0.1 +
        (sin(y * 0.11 + x * 0.013) + sin(y * 0.13 - x * 0.015)) * 5;
  });

  late final _interferencePaletteRebels = List.generate(16, (i) {
    double f = i / 16;
    double component(double f) => sin(f * 2 * pi) * 0.5 + 0.5;
    return Color.hsl(
      component(f) * 0.17 + 0.7,
      component(f) * 0.2 + 0.3,
      component(f * 2) * 0.15 + 0.1,
    );
  });

  void rebelsText(int P) {
    var interference = Interference();
    var interferencePalette = Interference.generatePaletteFromList(
      _interferencePaletteRebels,
    );

    Display interferenceDisplay(int frame) {
      return interference
          .frame(
            (sin(frame / 102 + 4.5) + sin(frame / 133)) / 2, // even X
            (sin(frame / 160 + 0.3) + sin(frame / 131)) / 2, // even Y
            (sin(frame / 175 + 0.2) + sin(frame / 163)) / 2, // odd X
            (sin(frame / 130 + 2.35) + sin(frame / 127)) / 2, // odd Y
            frame & 1 != 0, // flip
          )
          .display;
    }

    F(P, 0) >> interferencePalette;
    F(P, 0) - (P, 32, -1) |
        (frame, copper) {
          copper << interferenceDisplay(frame);
        };

    F(P, 0) >>
        (interferencePalette |
            spriteScreen.palette(Palette.fromMap({1: alice.palette[0]}), 240));
    F(P, 32) - (P + 1, 0, -64) |
        (frame, copper) {
          copper <<
              (interferenceDisplay(frame + 32 * 6)
                ..alignment = 2
                ..sprites = spriteScreen.labels
                ..spriteColorOffset = 240
                ..priority = 4);
        };

    transition(waveTrans, (P, 32), inverse: true);
  }
}
