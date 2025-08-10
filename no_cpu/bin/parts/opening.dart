import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/transition.dart';

mixin Opening on NoCpuDemoBase {
  late IlbmImage logoImage = IlbmImage.fromFile(
    "$assetsPath/DEMOSTUE ALLSTARS LOGO6.iff",
  );

  late IlbmImage oneBullyImage = IlbmImage.fromFile(
    "$assetsPath/ONE BULLY2.iff",
  );

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

    for (int p = 0; p < 4; p++) {
      F(P, 0, -1) << logoSprite1.blit(p);
      F(P, 0, -1) << logoSprite2.blit(p);
    }
    F(P, 0, -1) << logoSprite1.updatePosition(h: 0x200 + lx1 * 4, v: 82 + ly1);
    F(P, 0, -1) << logoSprite2.updatePosition(h: 0x200 + lx2 * 4, v: 82 + ly2);
    F(P, 0, -1) << logoSprite2.updateTerminator();
    F(P, 0) << pal;
    F(P, 0) - (P + 2, 0, -1) >>
        (Display()
          ..setBitmap(Bitmap.blank(320, 180, 1)) // TODO: interference
          ..sprites = logoSprite1.labels
          ..spriteColorOffset = 240);
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
