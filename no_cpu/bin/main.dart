import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import 'base.dart';
import 'effects/transition.dart';
import 'parts/opening.dart';
import 'parts/bully.dart';
import 'parts/text.dart';
import 'parts/rebels.dart';
import 'parts/together.dart';
import 'parts/check.dart';
import 'parts/credits.dart';
import 'parts/life.dart';

class NoCpuDemoBase extends MusicDemoBase {
  late Color afterCardColor = Color.rgb12(0x000);
  late Color oneBullyTransColor = Color.rgb12(0x000);
  late Color bullyTransColor = Color.rgb12(0x000);
  late Color togetherColor = Color.rgb12(0x444);
  late Color lifeColor = Color.rgb12(0xEC8);

  SpriteGroup spriteScreen = SpriteGroup.space(320, 180);

  late IlbmImage alice = IlbmImage.fromFile("$assetsPath/Cycle Alice.iff");
  late IlbmImage lisa = IlbmImage.fromFile("$assetsPath/Cycle Lisa.iff");
  late IlbmImage paula = IlbmImage.fromFile("$assetsPath/Cycle Paula.iff");

  late Bitmap aliceMask = alice.bitmap
      .transform((_, _, p) => p > 0 && p < 88 ? 1 : 0, depth: 1)
      .crop(h: 180);
  late Bitmap lisaMask = lisa.bitmap
      .transform((_, _, p) => p > 0 && p < 88 ? 1 : 0, depth: 1)
      .crop(h: 180);
  late Bitmap paulaMask = paula.bitmap
      .transform((_, _, p) => p > 0 && p < 58 || p >= 97 ? 1 : 0, depth: 1)
      .crop(h: 180);

  late Transition waveTrans = Transition.generate(320, 180, (x, y) {
    return 20 +
        x * (0.2 + y * 0.001) -
        y * 0.1 +
        (sin(y * 0.11 + x * 0.013) + sin(y * 0.13 - x * 0.015)) * 5;
  });

  late Transition lifeTrans = Transition.generate(320, 180, (x, y) {
    double dx = x - 160;
    double dy = y - 100;
    double d = sqrt(dx * dx + dy * dy);
    double v = atan2(dx, dy);
    return d * (0.3 + 0.15 * cos(v * 5 + d * 0.1));
  });

  NoCpuDemoBase()
    : super.withProtrackerFile(
        "$assetsPath/no cpu today.mod",
        startFrame: NoCpuDemo.startPattern * 64 * 6,
      );

  void transition(
    Transition trans,
    Object f, {
    int start = 0,
    int end = 128,
    bool backward = false,
    bool inverse = false,
    int rate = 1,
  }) {
    int frame = musicFrame(f);
    for (int i = 0; i <= end - start; i++) {
      frames[frame + i * rate] >> spriteScreen.blit(0, aBitmap: trans.result);
      frames[frame + i * rate - 1] <<
          trans.run(backward ? end - i : start + i, inverse: inverse);
    }
  }

  CopperComponent blankDisplay([Color? color]) {
    color ??= Color.rgb12(0x000);
    return Palette.fromMap({0: color}) >>
        (Display()
          ..setBitmap(Bitmap.blank(320, 1, 1))
          ..stride = 0);
  }
}

class NoCpuDemo extends NoCpuDemoBase
    with Opening, Bully, Text, Rebels, Together, Check, Credits, Life {
  static int startPattern = 0;

  NoCpuDemo() : super() {
    initialCopper << spriteScreen.blit(1);
    initialCopper << spriteScreen.updatePosition(v: 82);

    ratingCard(0);
    showLogo(2);
    oneBully(4);
    bully(6, bullyTransColor);
    rebelsText(8);
    rebels(9);
    together(15);
    checkerboardText(17);
    check(18);
    credits(22);
    joinText(25);
    life(26);
  }
}

main() {
  NoCpuDemo().build(
    categories: [
      ("Music copperlists", r"^Copper: MusicFrame"),
      ("Effect copperlists", r"^Copper: "),
      ("Instruments", r"^Instrument"),
      ("Transition patterns", r"^Bitmap .* x 7 data$"),
      ("Checkerboard row/column maps", r"^Bitmap .*(1024|437) "),
      ("Interference textures", r"^Bitmap 592 x 328"),
      ("Bitmap graphics", r"^Bitmap"),
      ("Sprite graphics", r"^Sprite [0-9]+( attached)?$"),
      ("Dispatch data", r"^Frame dispatch"),
      ("Other data", r""),
    ],
  );
}
