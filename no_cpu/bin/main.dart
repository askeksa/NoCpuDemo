import 'package:no_cpu/no_cpu.dart';

import 'base.dart';
import 'parts/opening.dart';
import 'parts/bully.dart';

class NoCpuDemoBase extends MusicDemoBase {
  NoCpuDemoBase() : super.withProtrackerFile("$assetsPath/keines cpu1.2.mod") {}
}

class NoCpuDemo extends NoCpuDemoBase with Opening, Bully {
  NoCpuDemo() : super() {
    ratingCard(0);
    bully(2, Color.rgb12(0x000));
  }
}

main() {
  NoCpuDemo().build();
}
