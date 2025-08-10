import 'dart:math';

import 'package:collection/collection.dart';
import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/transition.dart';
import '../effects/interference.dart';

mixin Opening on NoCpuDemoBase {
  late IlbmImage logoImage = IlbmImage.fromFile(
    "$assetsPath/DEMOSTUE ALLSTARS LOGO6.iff",
  );

  late IlbmImage oneBullyImage = IlbmImage.fromFile(
    "$assetsPath/ONE BULLY2.iff",
  );

  late final _interferencePalette = List.generate(16, (i) {
    double f = i / 16;
    double component(double f) => sin(f * 2 * pi) * 0.5 + 0.5;
    return Color.hsl(
      component(f) * 0.17 + 0.7,
      component(f) * 0.2 + 0.3,
      component(f * 2) * 0.15 + 0.1,
    );
  });

  final _blackPalette = Palette.generateRange(0, 128, (i) => Color.black);

  final _paletteIndices = List<int>.generate(128, (i) => i).shuffled();

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

  // Generate a palette suitable for the interference effect.
  // The generator function should return a Color object for each color index up to and including the maximum index
  static Palette _generatePalette(
    Color Function(int index, int maxIndex) generator,
  ) {
    var colors = List.generate(16, (i) => generator(i, 15));

    return Palette.generateRange(0, 256, (i) {
      int evenColor =
          ((i & 0x40) >> 3) |
          ((i & 0x10) >> 2) |
          ((i & 0x04) >> 1) |
          (i & 0x01);
      int oddColor = ((i & 0x20) >> 3) | ((i & 0x08) >> 2) | ((i & 0x02) >> 1);

      return colors[((oddColor << 1) + evenColor) & 15];
    });
  }

  static Palette _generatePaletteFromList(List<Color> palette) =>
      _generatePalette((index, _) => palette[index]);

  void ratingCard(int P) {
    var image = IlbmImage.fromFile("$assetsPath/Folcka_NO CPU WARNING.iff");
    F(P, 0) >> image.palette;
    F(P, 0) - (P + 1, 36, -1) >>
        (Display()..setBitmap(image.bitmap.crop(h: 180)));
    F(P + 1, 36) - (P + 2, 0, -1) << blankDisplay(afterCardColor);
  }

  void showLogo(int P) {
    var (lx1, ly1, logo1) = logoImage.bitmap.crop(h: 77).autocrop();
    var (lx2, ly2, logo2) = logoImage.bitmap
        .crop(x: 77, y: 77, h: 77)
        .autocrop();
    lx2 += 77;
    ly2 += 77;

    logo2 = logo2.crop(w: 192);
    var logoSprite1 = SpriteGroup.space(
      logo1.width,
      logo1.height,
      attached: true,
    );
    var logoSprite2 = SpriteGroup.space(
      logo2.width,
      logo2.height,
      attached: true,
      parent: logoSprite1,
    );
    var pal = logoSprite1.palette(logoImage.palette.sub(1, 15), 240);

    var trans = Transition.generate(192, 64, (x, y) {
      return 20 + x * 0.4 + 8 * (sin(x * 0.3) + sin(y * 0.3));
    });

    void blitToSprite(int _, Copper copper) {
      for (int p = 0; p < 4; p++) {
        copper <<
            logoSprite1.blit(
              p,
              aBitmap: logo1,
              aFromPlane: p,
              bBitmap: trans.result,
              minterms: A & B,
            ) <<
            logoSprite2.blit(
              p,
              aBitmap: logo2,
              aFromPlane: p,
              bBitmap: trans.result,
              minterms: A & B,
            );
      }
    }

    var interference = Interference();
    var interferencePalette = _generatePaletteFromList(_interferencePalette);
    var fadePalettes = List.generate(
      85,
      (i) => _randomPartialFade(i, _blackPalette, interferencePalette),
    );

    for (int p = 0; p < 4; p++) {
      F(P, 0, -1) << logoSprite1.blit(p);
      F(P, 0, -1) << logoSprite2.blit(p);
    }
    F(P, 0, -1) << logoSprite1.updatePosition(h: 0x200 + lx1 * 4, v: 82 + ly1);
    F(P, 0, -1) << logoSprite2.updatePosition(h: 0x200 + lx2 * 4, v: 82 + ly2);
    F(P, 0, -1) << logoSprite2.updateTerminator();
    F(P, 0) << pal;
    F(P, 0) - (P + 2, 0, -1) |
        (frame, copper) {
          copper <<
              (interference
                  .frame(
                    (sin(frame / 102 + 4.5) + sin(frame / 133)) / 2, // even X
                    (sin(frame / 160 + 0.3) + sin(frame / 131)) / 2, // even Y
                    (sin(frame / 175 + 0.2) + sin(frame / 163)) / 2, // odd X
                    (sin(frame / 130 + 2.35) + sin(frame / 127)) / 2, // odd Y
                    frame & 1 != 0, // flip
                  )
                  .display
                ..alignment = 1
                ..priority = 4
                ..sprites = logoSprite1.labels
                ..spriteColorOffset = 240);
        };

    F(P, 0, 0) << _blackPalette.sub(0, 127);

    F(P, 0, 1) - fadePalettes.length ^
        (frame, copper) {
          if (frame >= 0 && frame < fadePalettes.length) {
            copper << fadePalettes[frame];
          }
        };

    F(P + 2, 0, -fadePalettes.length - 1) - fadePalettes.length ^
        (frame, copper) {
          if (frame >= 0 && frame < fadePalettes.length) {
            copper << fadePalettes[fadePalettes.length - 1 - frame];
          }
        };

    F(P, 32) - 128 ^ blitToSprite;
    F(P, 32, -1) - 128 | (i, copper) => copper << trans.run(i, inverse: true);
    F(P + 1, 32) - 128 ^ blitToSprite;
    F(P + 1, 32, -1) - 128 |
        (i, copper) => copper << trans.run(128 - i, inverse: true);
  }

  void oneBully(int P) {
    var image = oneBullyImage.bitmap.crop(h: 180);
    var spritePalette1 = spriteScreen.palette(
      Palette.fromMap({1: oneBullyTransColor}),
      240,
    );
    var spritePalette2 = spriteScreen.palette(
      Palette.fromMap({1: bullyTransColor}),
      240,
    );

    var trans = Transition.generate(320, 180, (x, y) {
      double d = y * 0.1 + x * 0.01;
      return (5 + d.floor() * 5 - d * 4) * 3;
    });

    F(P, 0) << oneBullyImage.palette;
    F(P, 0) - (P + 2, 0, -1) <<
        (Display()
          ..setBitmap(image)
          ..sprites = spriteScreen.labels
          ..spriteColorOffset = 240
          ..priority = 4);

    F(P, 0) << spritePalette1;
    transition(trans, (P, 0));

    F(P + 1, 32) << spritePalette2;
    transition(trans, (P + 1, 32), backward: true);
  }
}
