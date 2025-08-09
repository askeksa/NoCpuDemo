import 'package:no_cpu/no_cpu.dart';

import 'base.dart';
import 'effects/transition.dart';
import 'parts/opening.dart';
import 'parts/bully.dart';
import 'parts/rebels.dart';
import 'parts/check.dart';
import 'parts/life.dart';

class NoCpuDemoBase extends MusicDemoBase {
  late Color afterCardColor = Color.rgb24(0x000000);
  late Color oneBullyTransColor = Color.rgb24(0x000000);
  late Color bullyTransColor = Color.rgb24(0x000000);

  SpriteGroup spriteScreen = SpriteGroup.space(320, 180);

  late IlbmImage alice = IlbmImage.fromFile(
    "$assetsPath/!ALICE CYCLE Done4.iff",
  );
  late IlbmImage lisa = IlbmImage.fromFile("$assetsPath/!LISA CYCLE done2.iff");
  late IlbmImage paula = IlbmImage.fromFile(
    "$assetsPath/!PAULA CYCLE DONE.iff",
  );

  late Bitmap aliceMask = alice.bitmap.transform(
    (x, y, p) => p == 0 ? 0 : 1,
    depth: 1,
  );
  late Bitmap lisaMask = lisa.bitmap.transform(
    (x, y, p) => p == 0 ? 0 : 1,
    depth: 1,
  );
  late Bitmap paulaMask = paula.bitmap.transform(
    (x, y, p) => p == 0 ? 0 : 1,
    depth: 1,
  );

  NoCpuDemoBase() : super.withProtrackerFile("$assetsPath/keines cpu1.10.mod") {
    startFrame = music.getTimestamp(0, 0);
  }

  void transition(
    Transition trans,
    Object f, {
    int start = 0,
    int end = 128,
    bool backward = false,
    bool inverse = false,
  }) {
    int frame = musicFrame(f);
    for (int i = 0; i <= end - start; i++) {
      frames[frame + i] >> spriteScreen.blit(0, aBitmap: trans.result);
      frames[frame + i - 1] <<
          trans.run(backward ? end - i : start + i, inverse: inverse);
    }
  }

  CopperComponent blankDisplay([Color? color]) {
    color ??= Color.rgb24(0x000000);
    return (Display()
          ..setBitmap(Bitmap.blank(320, 1, 1))
          ..stride = 0) +
        Palette.fromMap({0: color, 1: color});
  }
}

class NoCpuDemo extends NoCpuDemoBase with Opening, Bully, Rebels, Check, Life {
  NoCpuDemo() : super() {
    initialCopper << spriteScreen.blit(1);
    initialCopper << spriteScreen.updatePosition(v: 82);

    ratingCard(0);
    showLogo(2);
    oneBully(4);
    bully(6, bullyTransColor);
    F(8, 0) << Palette.fromMap({0: aliceBg});
    rebels(9);
    check(17);
    life(25);
  }
}

main() {
  NoCpuDemo().build();
}
