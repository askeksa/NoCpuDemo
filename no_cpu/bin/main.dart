import 'package:no_cpu/no_cpu.dart';

import 'base.dart';
import 'effects/transition.dart';
import 'parts/opening.dart';
import 'parts/bully.dart';
import 'parts/rebels.dart';
import 'parts/check.dart';
import 'parts/life.dart';

class NoCpuDemoBase extends MusicDemoBase {
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
    frames[frame - 1] >> spriteScreen.blit(1);
    for (int i = 0; i <= end - start; i++) {
      frames[frame + i] >> spriteScreen.blit(0, aBitmap: trans.result);
      frames[frame + i - 1] <<
          trans.run(backward ? end - i : start + i, inverse: inverse);
    }
  }
}

class NoCpuDemo extends NoCpuDemoBase with Opening, Bully, Rebels, Check, Life {
  NoCpuDemo() : super() {
    ratingCard(0);
    showLogo(2);
    bully(6, Color.rgb12(0x000));
    F(8, 0) << Palette.fromMap({0: aliceBg});
    rebels(9);
    check(17);
    life(25);
  }
}

main() {
  NoCpuDemo().build();
}
