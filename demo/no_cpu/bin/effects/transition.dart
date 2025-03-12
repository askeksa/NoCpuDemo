import 'package:no_cpu/no_cpu.dart';

class Transition {
  final Bitmap pattern;
  late Bitmap temp = Bitmap.space(pattern.width, pattern.height, 1);
  late Bitmap result = Bitmap.space(pattern.width, pattern.height, 1);

  Transition(this.pattern) : assert(pattern.depth == 7);

  Transition.generate(
    int width,
    int height,
    num Function(int x, int y) generator,
  ) : this(
        Bitmap.fromChunky(
          ChunkyPixels.generate(
            width,
            height,
            (x, y) => generator(x, y).clamp(0, 127).toInt(),
          ),
          depth: 7,
        ),
      );

  Transition.fromIlbm(IlbmImage image) : this(Bitmap.fromIlbm(image));

  Transition.fromFile(String path) : this.fromIlbm(IlbmImage.fromFile(path));

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

  Bitmap get pattern => transition.pattern;
  Bitmap get temp => transition.temp;
  Bitmap get result => transition.result;

  @override
  void addToCopper(Copper copper) {
    var pass1 =
        Blit()
          ..aSetBitplane(pattern, 2)
          ..bSetBitplane(pattern, 1)
          ..cSetBitplane(pattern, 0)
          ..dSetBitplane(temp, 0)
          ..minterms = (-1 << (threshold & 7)) & 0xFF;

    var pass2 =
        Blit()
          ..aSetBitplane(pattern, 4)
          ..bSetBitplane(pattern, 3)
          ..cdSetBitplane(temp, 0)
          ..minterms = (-2 << ((threshold >> 2) & 6)) & 0xFF;

    var pass3 =
        Blit()
          ..aSetBitplane(pattern, 6)
          ..bSetBitplane(pattern, 5)
          ..cSetBitplane(temp, 0)
          ..dSetBitplane(result, 0)
          ..minterms =
              ((-2 << ((threshold >> 4) & 14)) & 0xFF) ^ (inverse ? 0xFF : 0);

    copper << pass1 << pass2 << pass3;
  }
}
