import 'package:no_cpu/no_cpu.dart';

class Checkerboard {
  int width, height, layerCount, topline;

  late Bitmap rows = Bitmap.generate(
    1024,
    128,
    (x, y) => ((((x - 256) * 2 + width - 1023) * (5 + y)) >> 11) + 1 >> 1,
    depth: 1,
  )..bitplanes.block.alignment = 14;
  late Bitmap columns = Bitmap.generate(
    128,
    1 + 256 + height,
    (x, y) => ((((y - 1) * 2 - height - 255) * (5 + x)) >> 11) + 1 >> 1,
    depth: 1,
  )..bitplanes.block.alignment = 12;

  late Bitmap screen = Bitmap.space(width + 16, 1, layerCount);
  late Display display = Display()
    ..setBitmap(screen)
    ..stride = 0;
  late Space temp = Space(layerCount * 6, origin: "Checkerboard temp");
  late Data colors = Data.blank(4 << layerCount, origin: "Checkerboard colors")
    ..mutability = Mutability.mutable
    ..alignment = 2;

  late Copper subCopper = _makeCopper();

  Copper _makeCopper() {
    var polarities = FreeLabel.immutable("polarities");

    var effectCopper = Copper(mutability: Mutability.local);
    List<Label> blitLabels = [];
    var rowPtr = FreeLabel("rowPtr");
    var rowShift = FreeLabel("rowShift");
    var columnPtr = FreeLabel("columnPtr");
    var columnShift = FreeLabel("columnShift");
    var colorUpper = FreeLabel.immutable("colorUpper");
    var colorLower = FreeLabel.immutable("colorLower");
    for (int l = 0; l < layerCount; l++) {
      var rowBlit = Blit()
        ..aPtr = rows
            .bitplanes // rowPtr
        ..aShift =
            0 // rowShift
        ..dSetBitplane(screen, l, size: false)
        ..width = width ~/ 16 + 1
        ..descending = true;

      var columnBlit = Blit()
        ..aPtr = polarities + 14
        ..aLWM = (0xFF0000 >> l) & 0xFFFF
        ..aShift = 15
        ..bPtr = columns
            .bitplanes // columnPtr
        ..bShift =
            0 // columnShift
        ..bStride = columns.rowStride
        ..cData = 0x8000
        ..dPtr = polarities + 6
        ..adStride = 8
        ..minterms = A | (B & C)
        ..descending = true
        ..height = height + 1;

      var colorBlit = Blit()
        ..aData = 0xFFFF
        ..aFWM =
            0xFFF // colorUpper
        ..aLWM =
            0xFFF // colorLower
        ..dPtr = colors.label + (4 << l)
        ..emitModulos = true
        ..width = 2
        ..height = 1 << l;

      blitLabels.add(effectCopper.data.addLabel());
      if (l == 0) {
        effectCopper << rowBlit / {BLTAPTL: rowPtr, BLTCON0: rowShift};
        effectCopper << columnBlit / {BLTBPTL: columnPtr, BLTCON1: columnShift};
        effectCopper << colorBlit / {BLTAFWM: colorUpper, BLTALWM: colorLower};
      } else {
        effectCopper << rowBlit;
        effectCopper << columnBlit;
        effectCopper << colorBlit;
      }
    }

    if (layerCount < 8) {
      var adjustBlit = Blit()
        ..adPtr = polarities + 14
        ..adStride = 8
        ..aShift = 8 - layerCount
        ..height = height;

      effectCopper << adjustBlit;
    }

    effectCopper << DynamicPalette(colors.label, 0, 1 << layerCount);
    effectCopper.data.bind(polarities);
    for (int v = topline - 2; v < topline + height - 1; v++) {
      effectCopper.wait(v: v, h: 0xDF);
      effectCopper.move(BPLCON4, 0);
    }

    int blitStride = blitLabels[0] ^ blitLabels[1];
    var copyToTemp = Blit()
      ..channelMask = enableA | enableD
      ..dPtr = temp.label
      ..width = 3
      ..height = layerCount;
    var blitRowPtr1 = Blit()
      ..descending = true
      ..abPtr = temp.label
      ..abStride = 6
      ..aFWM = 0x00FE
      ..aShift = 6
      ..bShift = 5
      ..cData = 0x0020
      ..dPtr = rowPtr
      ..dStride = blitStride
      ..minterms = A | B & C
      ..height = layerCount;
    var blitRowPtr2 = Blit()
      ..aPtr = temp.label + 2
      ..aStride = 6
      ..aFWM = 0xF000
      ..aShift = 11
      ..bData =
          0x0000 // rowPtrData
      ..cdPtr = rowPtr
      ..cdStride = blitStride
      ..minterms = A | B | C
      ..height = layerCount;
    var blitRowShift = Blit()
      ..aPtr = temp.label + 4
      ..aStride = 6
      ..bData = 0xF000
      ..cdPtr = rowShift
      ..cdStride = blitStride
      ..minterms = (A & B) | (C & ~B)
      ..height = layerCount;
    var blitColumnPtr = Blit()
      ..aPtr = temp.label
      ..aFWM = 0xFFE0
      ..aShift = 4
      ..aStride = 6
      ..cData =
          0x0000 // columnPtrData
      ..dPtr = columnPtr
      ..dStride = blitStride
      ..minterms = A | C
      ..height = layerCount;
    var blitColumnShift = Blit()
      ..descending = true
      ..aPtr = temp.label
      ..aShift = 11
      ..aStride = 6
      ..bData = 0xF000
      ..cdPtr = columnShift
      ..cdStride = blitStride
      ..minterms = (A & B) | (C & ~B)
      ..height = layerCount;
    var blitUpperColors = Blit()
      ..aPtr = temp.label + 2
      ..aStride = 6
      ..cData = 0xFFF
      ..dPtr = colorUpper
      ..dStride = blitStride
      ..minterms = A & C
      ..height = layerCount;
    var blitLowerColors = Blit()
      ..aPtr = temp.label + 4
      ..aStride = 6
      ..cData = 0xFFF
      ..dPtr = colorLower
      ..dStride = blitStride
      ..minterms = A & C
      ..height = layerCount;

    var rowPtrData = FreeLabel("rowPtrData");
    var columnPtrData = FreeLabel("columnPtrData");

    var blitCopper = Copper(mutability: Mutability.local);
    blitCopper << copyToTemp;
    blitCopper << blitRowShift;
    blitCopper << blitColumnPtr / {BLTCDAT: columnPtrData};
    blitCopper.data.setLow(columnPtrData.offsetInBlock, columns.bitplanes);
    blitCopper << blitRowPtr1;
    blitCopper << blitRowPtr2 / {BLTBDAT: rowPtrData};
    blitCopper.data.setLow(rowPtrData.offsetInBlock, rows.bitplanes + 64);
    blitCopper << blitColumnShift;
    blitCopper << blitUpperColors;
    blitCopper << blitLowerColors;
    blitCopper.call(effectCopper);

    return blitCopper;
  }

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

  Display get display => checkerboard.display;
  Copper get subCopper => checkerboard.subCopper;

  CheckerboardFrame(this.checkerboard, this.layers);

  @override
  void addToCopper(Copper copper) {
    var layerData = Data(origin: this);
    for (var (x, y, d, color) in layers) {
      layerData.addWord((128 + y) << 8 | d << 1 | (~x & 0x0100) >> 8);
      layerData.addWord((x & 0x00f0) << 8 | color.upper);
      layerData.addWord((x & 0x000f) << 12 | color.lower);
    }

    copper >> display;
    copper.waitBlit();
    copper.ptr(BLTAPT, layerData.label);
    copper.call(subCopper);
  }
}
