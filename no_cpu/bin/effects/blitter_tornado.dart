import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

class BlitterTornado {
  static final _blockSize = 32;
  static final _border = _blockSize;
  final Bitmap bitmap1 = Bitmap.blank(320 + _border * 2, 192 + _border * 2, 1, mutability: Mutability.mutable);
  final Bitmap bitmap2 = Bitmap.blank(320 + _border * 2, 192 + _border * 2, 1, mutability: Mutability.mutable);

  static final List<Bitmap> _shapes = List.generate(16, (i) {
      Random rng = Random(i);
      return Bitmap.generate(64, 64, (x, y) => rng.nextInt(16) == 0 ? 1 : 0, depth: 1);
    });

  BlitterTornadoFrame frame(int frame, double angle, double zoom) {
    return BlitterTornadoFrame(this, frame, angle, zoom, Random(frame & 15));
  }
}

class BlitterTornadoFrame implements CopperComponent {
  BlitterTornado blitterTornado;
  int frame;
  double angle;
  double zoom;
  Random random;

  BlitterTornadoFrame(this.blitterTornado, this.frame, this.angle, this.zoom, this.random);

  @override
  void addToCopper(Copper copper) {

    var flip = frame & 1 != 0;

    var back = flip ? blitterTornado.bitmap1 : blitterTornado.bitmap2;
    var front = flip ? blitterTornado.bitmap2 : blitterTornado.bitmap1;

    var display = Display()
      ..horizontalScroll = BlitterTornado._border * 4
      ..verticalScroll = BlitterTornado._border
      ..setBitmap(front);

    copper >> display;

    copper ^ (copper) {
      copper.move(COLOR00, 0x0);
      copper.move(BPLCON3, 0);
      /*
      var screenCopy = Blit()
        ..aPtr = front.bitplanes
        ..aStride = front.rowStride
        ..dPtr = back.bitplanes
        ..dStride = back.rowStride
        ..width = front.width >> 4
        ..height = front.height;

      copper << screenCopy;
      */

      var angle = this.angle * (pi * 2 / 360);

      var dx = cos(angle) / zoom;
      var dy = sin(angle) / zoom;

      var offsetX = (frame & 1) * 16;
      var offsetY = (frame & 2) * 8;

      for (int y = 0; y < back.height; y += BlitterTornado._blockSize) {
        for (int x = back.width - BlitterTornado._blockSize; x >= 0; x -= BlitterTornado._blockSize) {
          var center = -16;

          var centerDestX = x + BlitterTornado._blockSize ~/ 2 - back.width ~/ 2 + offsetX + center;
          var centerDestY = y + BlitterTornado._blockSize ~/ 2 - back.height ~/ 2 + offsetY + center;
          var centerSrcX = (centerDestX * dx + centerDestY * dy).round();
          var centerSrcY = (centerDestY * dx - centerDestX * dy).floor();

          var destX = centerDestX - center - BlitterTornado._blockSize ~/ 2 + back.width ~/ 2;
          var destY = centerDestY - center - BlitterTornado._blockSize ~/ 2 + back.height ~/ 2;
          var srcX = centerSrcX - center - BlitterTornado._blockSize ~/ 2 + back.width ~/ 2;
          var srcY = centerSrcY - center - BlitterTornado._blockSize ~/ 2 + back.height ~/ 2;

          var width = BlitterTornado._blockSize;
          var height = BlitterTornado._blockSize;

          if (destX < 0) {
            width += destX;
            destX = 0;
          }

          if (destY < 0) {
            height += destX;
            destX = 0;
          }

          if (destX + width > back.width) {
            width = back.width - destX;
          }

          if (destY + height > back.height) {
            height = back.height - destY;
          }

          /*
          var width = min(BlitterTornado._blockSize, back.width - destX);
          var height = min(BlitterTornado._blockSize, back.height - destY);

          int clip(int n) {
            if (n < 0) {
              width += n;
              destX += n;
              return 0;
            } else {
              return n;
            }
          }

          if (srcX < 0) {
            width += srcX;
            destX += srcX;
            srcX = 0;
          }

          if (destX < 0) {
            width += destX;
            srcX += destX;
            destX = 0;
          }

          if (srcY < 0) {
            height += srcY;
            destY += srcY;
            srcY = 0;
          }

          if (destX >= back.width || destY >= back.height || destX <= -BlitterTornado._blockSize || destY <= -BlitterTornado._blockSize) continue;
          */


          var wordWidth = width ~/ 16;
          var destWord = destX ~/ 16 + destY * back.rowStride ~/ 2;
          var srcWord = srcX ~/ 16 + srcY * front.rowStride ~/ 2;
          var shift = srcX & 15;

          if (shift != 0) {
            shift = 16 - shift;
            destWord -= 1;
            wordWidth += 1;
          }

          // Shift the source to the right
          var blit = 
            Blit()
              ..aPtr = front.bitplanes + srcWord * 2
              ..aStride = front.bytesPerRow
              ..aShift = shift
              ..dPtr = back.bitplanes + destWord * 2
              ..dStride = back.bytesPerRow
              ..width = wordWidth
              ..height = height;
          copper << blit;
        }
      }

      var shape = BlitterTornado._shapes[frame & 15];
      var destPtr = back.bitplanes + back.rowStride * ((back.height - shape.height) ~/ 2 - offsetX) + ((back.width - shape.width) ~/ 2 - offsetY) ~/ 8;
      var shapeBlit = 
        Blit()
          ..aPtr = shape.bitplanes
          ..aStride = shape.rowStride
          ..cdPtr = destPtr
          ..cdStride = back.rowStride
          ..minterms = A ^ C
          ..width = shape.width >> 4
          ..height = shape.height;

      copper << shapeBlit;

      copper.move(COLOR00, 0x800);
    };
  }
}
