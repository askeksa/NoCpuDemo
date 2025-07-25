import 'dart:collection';

import 'bitmap.dart';
import 'bitmap_blit.dart';
import 'blitter.dart';
import 'color.dart';
import 'iff.dart';
import 'memory.dart';

(int, int) spriteControlWords(int v, int h, int height, bool attached) {
  int vEnd = v + height;
  int posReg = (v & 0xFF) << 8 | (h & 0x7F8) >> 3;
  int ctlReg =
      (vEnd & 0xFF) << 8 |
      (attached ? 0x0080 : 0x0000) |
      (v & 0x200) >> 3 |
      (vEnd & 0x200) >> 4 |
      (h & 0x3) << 3 |
      (v & 0x100) >> 6 |
      (vEnd & 0x100) >> 7 |
      (h & 0x4) >> 2;
  return (posReg, ctlReg);
}

class Sprite {
  late final Label label;
  final int height;
  final bool attached;

  late final bitmap = Bitmap(64, height, 2, 8, label + 16, interleaved: true);

  Sprite(this.label, this.height, {this.attached = false});

  Sprite.space(this.height, {this.attached = false}) {
    label = Space((height + 2) * 16, alignment: 3).label;
  }

  Sprite.blank(
    this.height, {
    this.attached = false,
    Mutability mutability = Mutability.mutable,
  }) {
    label = Data.blank(
      (height + 2) * 16,
      alignment: 3,
      mutability: mutability,
    ).label;
  }

  factory Sprite.generate(
    int height,
    int Function(int x, int y) generator, {
    bool attached = false,
    Mutability mutability = Mutability.mutable,
  }) {
    var sprite = Sprite.blank(
      height,
      attached: attached,
      mutability: mutability,
    );
    return sprite..fill(generator);
  }

  factory Sprite.fromBitmap(
    Bitmap bitmap, {
    bool attached = false,
    Mutability mutability = Mutability.mutable,
  }) {
    return Sprite.generate(
      bitmap.height,
      bitmap.getPixel,
      attached: attached,
      mutability: mutability,
    );
  }

  factory Sprite.fromIlbm(IlbmImage image) {
    return Sprite.fromBitmap(Bitmap.fromIlbm(image));
  }

  factory Sprite.fromFile(String path) {
    return Sprite.fromIlbm(IlbmImage.fromFile(path));
  }

  void fill(int Function(int x, int y) generator) {
    bitmap.fill(generator);
  }

  void setPosition({required int v, int h = 0x200}) {
    var (posReg, ctlReg) = spriteControlWords(v, h, height, attached);
    label.setWord(posReg);
    (label + 8).setWord(ctlReg);
  }

  Blit updatePosition({required int v, int h = 0x200}) {
    var (posReg, ctlReg) = spriteControlWords(v, h, height, attached);
    Data data = Data.fromWords([posReg, ctlReg]);
    return Blit()
      ..cPtr = data.label
      ..dPtr = label
      ..dStride = 8
      ..height = 2;
  }

  Blit blit(
    int plane, {
    Bitmap? aBitmap,
    Bitmap? bBitmap,
    Bitmap? cBitmap,
    int? minterms,
    int fromPlane = 0,
    int x = 0,
    int y = 0,
  }) {
    assert(plane >= 0 && plane < 2);
    assert(
      fromPlane >= 0 &&
          [?aBitmap, ?bBitmap, ?cBitmap].every((b) => fromPlane < b.depth),
    );
    Blit blit = Blit()..dSetBitplane(bitmap, plane);
    if (aBitmap != null) {
      blit.aSetBitplane(aBitmap, fromPlane, x: x, y: y, w: 64, h: height);
    }
    if (bBitmap != null) {
      blit.bSetBitplane(bBitmap, fromPlane, x: x, y: y, w: 64, h: height);
    }
    if (cBitmap != null) {
      blit.cSetBitplane(cBitmap, fromPlane, x: x, y: y, w: 64, h: height);
    }
    if (minterms != null) {
      blit.minterms = minterms;
    }
    return blit;
  }
}

class SpriteInGroup {
  final Sprite sprite;
  final int index;
  final int xOffset;
  final int planeOffset;

  SpriteInGroup(this.sprite, this.index, this.xOffset, this.planeOffset)
    : assert(index >= 0 && index < 8, "Sprite index must be between 0 and 7");
}

class SpriteGroup {
  final List<SpriteInGroup> sprites = [];
  final bool attached;

  List<Label> get labels {
    List<Label> labels = [];
    for (var s in sprites) {
      while (labels.length <= s.index) {
        labels.add(emptySprite);
      }
      labels.add(s.sprite.label);
    }
    return labels;
  }

  SpriteGroup._(
    Sprite Function(int, {required bool attached}) spriteFactory,
    int width,
    int height, {
    required int baseIndex,
    required this.attached,
    required bool sameParity,
  }) {
    if (attached && baseIndex & 0x1 != 0) {
      throw ArgumentError(
        "Base index for attached sprites must be even, got $baseIndex",
      );
    }
    int index = baseIndex;
    for (int xOffset = 0; xOffset < width; xOffset += 64) {
      sprites.add(
        SpriteInGroup(
          spriteFactory(height, attached: false),
          index,
          xOffset,
          0,
        ),
      );
      if (attached) {
        sprites.add(
          SpriteInGroup(
            spriteFactory(height, attached: true),
            index + 1,
            xOffset,
            2,
          ),
        );
      }
      index += attached || sameParity ? 2 : 1;
    }
  }

  factory SpriteGroup.space(
    int width,
    int height, {
    int baseIndex = 0,
    bool attached = false,
    bool sameParity = false,
  }) {
    return SpriteGroup._(
      Sprite.space,
      width,
      height,
      baseIndex: baseIndex,
      attached: attached,
      sameParity: sameParity,
    );
  }

  factory SpriteGroup.blank(
    int width,
    int height, {
    int baseIndex = 0,
    bool attached = false,
    bool sameParity = false,
    Mutability mutability = Mutability.mutable,
  }) {
    return SpriteGroup._(
      (int height, {required bool attached}) =>
          Sprite.blank(height, attached: attached, mutability: mutability),
      width,
      height,
      baseIndex: baseIndex,
      attached: attached,
      sameParity: sameParity,
    );
  }

  factory SpriteGroup.generate(
    int width,
    int height,
    int Function(int x, int y) generator, {
    int baseIndex = 0,
    bool attached = false,
    bool sameParity = false,
    Mutability mutability = Mutability.mutable,
  }) {
    return SpriteGroup.blank(
      width,
      height,
      baseIndex: baseIndex,
      attached: attached,
      sameParity: sameParity,
      mutability: mutability,
    )..fill(generator);
  }

  factory SpriteGroup.fromBitmap(
    Bitmap bitmap, {
    int baseIndex = 0,
    bool attached = false,
    bool sameParity = false,
    Mutability mutability = Mutability.mutable,
  }) {
    return SpriteGroup.generate(
      bitmap.width,
      bitmap.height,
      bitmap.getPixel,
      baseIndex: baseIndex,
      attached: attached,
      sameParity: sameParity,
      mutability: mutability,
    );
  }

  factory SpriteGroup.fromIlbm(
    IlbmImage image, {
    int baseIndex = 0,
    bool attached = false,
    bool sameParity = false,
    Mutability mutability = Mutability.mutable,
  }) {
    return SpriteGroup.fromBitmap(
      Bitmap.fromIlbm(image),
      baseIndex: baseIndex,
      attached: attached,
      sameParity: sameParity,
      mutability: mutability,
    );
  }

  factory SpriteGroup.fromFile(
    String path, {
    int baseIndex = 0,
    bool attached = false,
    bool sameParity = false,
    Mutability mutability = Mutability.mutable,
  }) {
    return SpriteGroup.fromIlbm(
      IlbmImage.fromFile(path),
      baseIndex: baseIndex,
      attached: attached,
      sameParity: sameParity,
      mutability: mutability,
    );
  }

  void fill(int Function(int x, int y) generator) {
    for (var s in sprites) {
      s.sprite.fill((x, y) => generator(x + s.xOffset, y) >> s.planeOffset);
    }
  }

  void setPosition({required int v, int h = 0x200}) {
    for (var s in sprites) {
      s.sprite.setPosition(v: v, h: h + s.xOffset * 4);
    }
  }

  List<Blit> updatePosition({required int v, int h = 0x200}) {
    return [
      for (var s in sprites)
        s.sprite.updatePosition(v: v, h: h + s.xOffset * 4),
    ];
  }

  List<Blit> blit(
    int plane, {
    Bitmap? aBitmap,
    Bitmap? bBitmap,
    Bitmap? cBitmap,
    int? minterms,
    int fromPlane = 0,
    int x = 0,
    int y = 0,
  }) {
    return [
      for (var s in sprites)
        if (plane >= s.planeOffset && plane < s.planeOffset + 2)
          s.sprite.blit(
            plane - s.planeOffset,
            aBitmap: aBitmap,
            bBitmap: bBitmap,
            cBitmap: cBitmap,
            minterms: minterms,
            fromPlane: fromPlane,
            x: x + s.xOffset,
            y: y,
          ),
    ];
  }

  Palette palette(Palette spritePalette, [int evenOffset = 0, int? oddOffset]) {
    oddOffset ??= evenOffset;
    assert(evenOffset & ~0xF0 == 0, "Even offset must be a multiple of 16");
    assert(oddOffset & ~0xF0 == 0, "Odd offset must be a multiple of 16");

    if (attached) {
      assert(
        spritePalette.colors.keys.every((k) => k >= 1 && k <= 15),
        "Palette indices for attached sprites must be between 1 and 15",
      );
      return spritePalette.shift(oddOffset);
    }

    assert(
      spritePalette.colors.keys.every((k) => k >= 1 && k <= 3),
      "Palette indices for unattached sprites must be between 1 and 3",
    );
    var colors = SplayTreeMap<int, Color>();
    for (var sprite in sprites) {
      int index = sprite.index;
      int offset = index.isEven ? evenOffset : oddOffset;
      int spriteOffset = (index & 0x6) << 1;
      for (var color in spritePalette.colors.entries) {
        colors[offset + spriteOffset + color.key] = color.value;
      }
    }
    return Palette(colors);
  }
}

Label emptySprite = Data.blank(
  16,
  alignment: 3,
  mutability: Mutability.immutable,
).label;
