import 'package:no_cpu/no_cpu.dart';

class Transition {
  final Bitmap pattern;
  late Bitmap temp = Bitmap.space(pattern.width, pattern.height, 1);
  late Bitmap result = Bitmap.space(pattern.width, pattern.height, 1);

  late Copper subCopper = _makeCopper();

  Transition(this.pattern) : assert(pattern.depth == 7);

  Transition.generate(
    int width,
    int height,
    num Function(int x, int y) generator,
  ) : this(
        Bitmap.generate(
          width,
          height,
          (x, y) => generator(x, y).clamp(0, 127).toInt(),
          depth: 7,
        ),
      );

  Transition.fromIlbm(IlbmImage image) : this(Bitmap.fromIlbm(image));

  Transition.fromFile(String path) : this.fromIlbm(IlbmImage.fromFile(path));

  Copper _makeCopper() {
    var modulo = FreeLabel("modulo");
    var con1 = FreeLabel("con1");
    var con2 = FreeLabel("con2");
    var con3 = FreeLabel("con3");

    var setcon =
        Blit()
          ..channelMask = enableC | enableD
          ..dPtr = con1
          ..height = 3;

    var pass1 =
        Blit()
          ..aSetBitplane(pattern, 2)
          ..bSetBitplane(pattern, 1)
          ..cSetBitplane(pattern, 0)
          ..dSetBitplane(temp, 0);

    var pass2 =
        Blit()
          ..aSetBitplane(pattern, 4)
          ..bSetBitplane(pattern, 3)
          ..cdSetBitplane(temp, 0);

    var pass3 =
        Blit()
          ..aSetBitplane(pattern, 6)
          ..bSetBitplane(pattern, 5)
          ..cSetBitplane(temp, 0)
          ..dSetBitplane(result, 0);

    Copper copper = Copper(mutability: Mutability.local);
    copper << setcon / {BLTDMOD: modulo};
    copper << pass1 / {BLTCON0: con1};
    copper << pass2 / {BLTCON0: con2};
    copper << pass3 / {BLTCON0: con3};

    int stride = con1 ^ con2;
    assert(con2 ^ con3 == stride);
    modulo.setWord(stride - 2);

    return copper;
  }

  /// Set bits in the result where the corresponding pixel in the pattern is
  /// greater or equal to (less than, if [inverse] is true) the [threshold].
  CopperComponent run(int threshold, {bool inverse = false}) {
    assert(threshold >= 0 && threshold <= 128);
    return TransitionRun(this, threshold, inverse);
  }
}

class TransitionRun implements CopperComponent {
  final Transition transition;
  final int threshold;
  final bool inverse;

  TransitionRun(this.transition, this.threshold, this.inverse);

  @override
  void addToCopper(Copper copper) {
    int minterms1 = (-1 << (threshold & 7)) & 0xFF;
    int minterms2 = (-2 << ((threshold >> 2) & 6)) & 0xFF;
    int minterms3 =
        ((-2 << ((threshold >> 4) & 14)) & 0xFF) ^ (inverse ? 0xFF : 0);

    Data data = Data();
    data.addWord(0x0F00 | minterms1);
    data.addWord(0x0F00 | minterms2);
    data.addWord(0x0F00 | minterms3);

    copper.ptr(BLTCPT, data.label);
    copper.call(transition.subCopper);
  }
}
