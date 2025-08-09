import 'package:no_cpu/no_cpu.dart';

import '../base.dart';
import '../main.dart';
import '../effects/interference.dart';

mixin Opening on NoCpuDemoBase {
  late IlbmImage logoImage = IlbmImage.fromFile(
    "$assetsPath/DEMOSTUE ALLSTARS LOGO6.iff",
  );

  void ratingCard(int P) {
    var image = IlbmImage.fromFile("$assetsPath/Folcka_NO CPU WARNING.iff");
    F(P, 0) >> image.palette;
    F(P, 0) - (P + 1, 36, -1) >>
        (Display()..setBitmap(image.bitmap.crop(h: 180)));
    F(P + 1, 36) >> Display();
  }

  void showLogo(int P) {
    var (lx, ly, logo) = logoImage.bitmap.crop(h: 180).autocrop();
    var logoSprite = SpriteGroup.fromBitmap(logo, attached: true);
    logoSprite.setPosition(h: 0x200 + lx * 4, v: 82 + ly);
    var pal =
        logoImage.palette.sub(0, 0) |
        logoSprite.palette(logoImage.palette.sub(1, 15), 240);
    F(P, 0) >> pal;
    F(P, 0) - (P + 1, 0, -1) >>
        (Display()
          ..bitplanes =
              [logoImage.bitmap.bitplanes] // TODO
          ..sprites = logoSprite.labels
          ..spriteColorOffset = 240);
    F(P + 1, 0) >> Display();
  }
}
