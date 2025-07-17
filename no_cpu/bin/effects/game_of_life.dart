import 'package:no_cpu/no_cpu.dart';

class GameOfLife {
  final int width, height;
  final int xmargin, ymargin;

  Bitmap makeBitmap() => Bitmap.space(width - xmargin + 2, height - ymargin, 1);

  late Bitmap s = makeBitmap();
  late Bitmap d = makeBitmap();
  late Bitmap s12 = makeBitmap();
  late Bitmap s13 = s;
  late Bitmap d13 = makeBitmap();
  late Bitmap d23 = d;
  late Bitmap t1 = s12;
  late Bitmap t2 = t1;

  static const int C0 = NANBNC;
  static const int C1 = ANBNC | NABNC | NANBC;
  static const int C2 = ABNC | ANBC | NABC;
  static const int C3 = ABC;

  GameOfLife(this.width, this.height, this.xmargin, this.ymargin)
    : assert(width & 0xF == 0),
      assert(xmargin >= 2),
      assert(ymargin >= 0);

  List<Blit> step(Bitmap t) {
    Blit b(
      Bitmap a,
      Bitmap b,
      Bitmap c,
      Bitmap d,
      int aShift,
      int bShift,
      int minterms, {
      int rw = 0,
      int sy = 0,
      int y = 0,
      int? h,
      bool descending = false,
    }) {
      int wh = height - ymargin;
      h ??= wh - sy * 2;
      return Blit()
        ..aSetBitplane(
          a,
          0,
          x: xmargin - rw,
          y: (y + wh) % wh,
          w: width - xmargin + rw,
          h: h,
        )
        ..bSetBitplane(
          b,
          0,
          x: xmargin - rw,
          y: (y + sy + wh) % wh,
          w: width - xmargin + rw,
          h: h,
        )
        ..cSetBitplane(
          c,
          0,
          x: xmargin - rw,
          y: (y + sy * 2 + wh) % wh,
          w: width - xmargin + rw,
          h: h,
        )
        ..dSetBitplane(
          d,
          0,
          x: xmargin - rw,
          y: (y + sy + wh) % wh,
          w: width - xmargin + rw,
          h: h,
        )
        ..aShift = aShift
        ..bShift = bShift
        ..minterms = minterms
        ..descending = descending;
    }

    return [
      // Singles, with wrap
      b(t, t, t, s, 0, 0, C1 | C3, rw: 2, sy: 1, y: -1, h: 1),
      b(t, t, t, s, 0, 0, C1 | C3, rw: 2, sy: 1, y: 0),
      b(t, t, t, s, 0, 0, C1 | C3, rw: 2, sy: 1, y: height - ymargin - 2, h: 1),
      // Doubles, with wrap
      b(t, t, t, d, 0, 0, C2 | C3, rw: 2, sy: 1, y: -1, h: 1),
      b(t, t, t, d, 0, 0, C2 | C3, rw: 2, sy: 1),
      b(t, t, t, d, 0, 0, C2 | C3, rw: 2, sy: 1, y: height - ymargin - 2, h: 1),
      // Count singles
      b(s, s, s, s12, 2, 1, C1 | C2, rw: 2),
      b(s, s, s, s13, 2, 1, C1 | C3, rw: 2),
      // Count doubles
      b(d, d, d, d13, 2, 1, C1 | C3, rw: 2),
      b(d, d, d, d23, 2, 1, C2 | C3, rw: 2),
      // Combine
      b(s12, d13, d23, t1, 0, 0, NANBNC | ABNC | NANBC),
      b(t1, s13, d23, t2, 0, 0, A & ~(B & C)),
      b(t2, s13, t, t, 1, 1, A & (B | C), rw: 1, descending: true),
      // Wrap horizontally
      Blit()
        ..aSetBitplane(t, 0, x: xmargin - 1, w: 1)
        ..bData = 0x0001
        ..cdSetBitplane(t, 0, x: width - 1, w: 1)
        ..aShift = 15 - ((xmargin - 1) & 15)
        ..minterms = (A & B) | (C & ~B),
      Blit()
        ..descending = true
        ..aData = 0xFFFF
        ..aFWM = 0xFFFF
        ..aLWM = 0xFFFF << (15 - ((xmargin - 2) & 15))
        ..bSetBitplane(t, 0, x: width - xmargin, w: xmargin - 1)
        ..cdSetBitplane(t, 0, x: 0, w: xmargin - 1)
        ..bShift = 15 - ((xmargin - 1) & 15)
        ..minterms = (A & B) | (~A & C),
      // Wrap vertically
      if (ymargin > 0)
        Blit()
          ..aSetBitplane(t, 0, y: 0, h: ymargin)
          ..dSetBitplane(t, 0, y: height - ymargin, h: ymargin),
    ];
  }
}
