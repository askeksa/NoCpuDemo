import 'package:no_cpu/no_cpu.dart';

import 'base.dart';
import 'parts/opening.dart';
import 'parts/bully.dart';
import 'parts/rebels.dart';

class NoCpuDemoBase extends MusicDemoBase {
  NoCpuDemoBase() : super.withProtrackerFile("$assetsPath/keines cpu1.5.mod") {
    startFrame = music.getTimestamp(8, 32);
  }
}

class NoCpuDemo extends NoCpuDemoBase with Opening, Bully, Rebels {
  NoCpuDemo() : super() {
    ratingCard(0);
    bully(6, Color.rgb12(0x000));
    rebels(9);
  }
}

main() {
  NoCpuDemo().build();
}
