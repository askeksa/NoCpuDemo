import 'bitmap.dart';
import 'blitter.dart';
import 'copper.dart';
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
    label =
        (Data(alignment: 3, mutability: mutability)
          ..addSpace((height + 2) * 16)).label;
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

  void fill(int Function(int x, int y) generator) {
    bitmap.fill(generator);
  }

  void setPosition({required int v, int h = 0x200}) {
    var (posReg, ctlReg) = spriteControlWords(v, h, height, attached);
    label.setWord(posReg);
    (label + 8).setWord(ctlReg);
  }

  CopperComponent updatePosition({required int v, int h = 0x200}) {
    var (posReg, ctlReg) = spriteControlWords(v, h, height, attached);
    Data data =
        Data()
          ..addWord(posReg)
          ..addWord(ctlReg);
    return Blit()
      ..cPtr = data.label
      ..dPtr = label
      ..dStride = 8
      ..height = 2;
  }
}
