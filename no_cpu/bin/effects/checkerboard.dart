import 'package:no_cpu/no_cpu.dart';

class Checkerboard {
  int width, height, layerCount, topline;

  late Bitmap rows = Bitmap.generate(
    1024,
    128,
    (x, y) => ((((x - 16) * 2 + width - 1023) * (5 + y)) >> 11) + 1 >> 1,
    depth: 1,
  )..bitplanes.block.alignment = 10 - 3;
  late Bitmap columns = Bitmap.generate(
    128,
    1 + 256 + height,
    (x, y) => ((((y - 1) * 2 - height - 255) * (5 + x)) >> 11) + 1 >> 1,
    depth: 1,
  )..bitplanes.block.alignment = 7 - 3;

  late Bitmap screen = Bitmap.space(width + 16, 1, layerCount);
  late Display display = Display()
    ..setBitmap(screen)
    ..stride = 0;
  late Data colors = Data.blank(4 << layerCount);

  Checkerboard(this.width, this.height, this.layerCount, this.topline)
    : assert(layerCount >= 1 && layerCount <= 8);

  CheckerboardFrame frame(List<(int, int, int, Color)> layers) {
    assert(layers.length == layerCount);
    return CheckerboardFrame(this, layers);
  }
}

class CheckerboardFrame implements CopperComponent {
  final Checkerboard checkerboard;
  List<(int, int, int, Color)> layers;

  CheckerboardFrame(this.checkerboard, this.layers);

  @override
  void addToCopper(Copper copper) {
    copper << checkerboard.display;
    var polarities = FreeLabel.immutable("polarities");

    for (int l = 0; l < layers.length; l++) {
      final (x, y, d, color) = layers[l];
      assert(d >= 0 && d < 128);

      var rowBlit = Blit()
        ..aSetBitplane(
          checkerboard.rows,
          0,
          x: 512 - checkerboard.width + 16 + x,
          y: d,
          size: false,
        )
        ..aShift = x & 15
        ..dSetBitplane(checkerboard.screen, l)
        ..descending = true;

      var columnBlit = Blit()
        ..aPtr = polarities + 14
        ..aLWM = (0xFF0000 >> l) & 0xFFFF
        ..aShift = 15
        ..bSetBitplane(
          checkerboard.columns,
          0,
          x: d,
          y: 128 + y,
          w: 1,
          h: checkerboard.height + 1,
        )
        ..bShift = d & 15
        ..cData = 0x8000
        ..dPtr = polarities + 6
        ..adStride = 8
        ..minterms = A | (B & C)
        ..descending = true;

      var colorBlit = Blit()
        ..aData = 0xFFFF
        ..aFWM = color.upper
        ..aLWM = color.lower
        ..dPtr = checkerboard.colors.label + (4 << l)
        ..width = 2
        ..height = 1 << l;

      copper << rowBlit;
      copper << columnBlit;
      copper << colorBlit;
    }

    if (checkerboard.layerCount < 8) {
      var adjustBlit = Blit()
        ..adPtr = polarities + 14
        ..adStride = 8
        ..aShift = 8 - checkerboard.layerCount
        ..height = checkerboard.height;

      copper << adjustBlit;
    }

    copper >>
        DynamicPalette(
          checkerboard.colors.label,
          0,
          1 << checkerboard.layerCount,
        );

    copper.data.bind(polarities);
    for (
      int v = checkerboard.topline - 2;
      v < checkerboard.topline + checkerboard.height - 1;
      v++
    ) {
      copper.wait(v: v, h: 0xDF);
      copper.move(BPLCON4, 0);
    }
  }
}
