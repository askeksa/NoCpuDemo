import 'dart:typed_data';

import 'memory.dart';

class ChunkyPixels {
  final int width;
  final int height;
  final Uint8List pixels;

  ChunkyPixels(this.width, this.height) : pixels = Uint8List(width * height);

  factory ChunkyPixels.generate(
    int width,
    int height,
    int Function(int x, int y) generator,
  ) {
    var pixels = ChunkyPixels(width, height);
    int i = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        pixels.pixels[i++] = generator(x, y);
      }
    }
    return pixels;
  }

  int getPixel(int x, int y) => pixels[y * width + x];
  void setPixel(int x, int y, int value) {
    pixels[y * width + x] = value;
  }
}

class Bitmap {
  final int width;
  final int height;
  final int depth;
  final int alignment;
  final bool interleaved;

  late final int bytesPerRow;
  late final Label bitplanes;

  int get rowStride => interleaved ? depth * bytesPerRow : bytesPerRow;
  int get planeStride => interleaved ? bytesPerRow : height * bytesPerRow;
  int get sizeInBytes => depth * height * bytesPerRow;

  static int bytesPerRowFor(int width, int alignment) =>
      ((width + (8 << alignment) - 1) & ~((8 << alignment) - 1)) >> 3;

  static int sizeFor(int width, int height, int depth, int alignment) =>
      depth * height * bytesPerRowFor(width, alignment);

  Bitmap(
    this.width,
    this.height,
    this.depth,
    this.bytesPerRow,
    this.bitplanes, {
    this.alignment = 3,
    this.interleaved = false,
  }) : assert(bitplanes.isAlignedTo(alignment));

  Bitmap.space(
    this.width,
    this.height,
    this.depth, {
    this.alignment = 3,
    this.interleaved = false,
    bool singlePage = false,
  }) {
    bytesPerRow = bytesPerRowFor(width, alignment);
    var space = Space(
      sizeInBytes,
      alignment: alignment,
      singlePage: singlePage,
      origin: this,
    );
    bitplanes = space.label;
  }

  Bitmap.blank(
    this.width,
    this.height,
    this.depth, {
    this.alignment = 3,
    this.interleaved = false,
    bool singlePage = false,
  }) {
    bytesPerRow = bytesPerRowFor(width, alignment);
    var data = Data(alignment: alignment, singlePage: singlePage, origin: this)
      ..addSpace(sizeInBytes);
    bitplanes = data.label;
  }

  factory Bitmap.fromChunky(
    ChunkyPixels pixels, {
    int depth = 8,
    int alignment = 3,
    bool interleaved = false,
    bool singlePage = false,
  }) {
    // "Convert chunky to planar". Good enough for now.
    var bitmap = Bitmap.blank(
      pixels.width,
      pixels.height,
      depth,
      alignment: alignment,
      interleaved: interleaved,
      singlePage: singlePage,
    );

    final data = (bitmap.bitplanes.block as Data).bytes;
    final bpr = bitmap.bytesPerRow;
    final rowStride = bitmap.rowStride;
    final planeStride = bitmap.planeStride;

    for (var y = 0; y < pixels.height; y++) {
      for (var x = 0; x < pixels.width; x++) {
        final pixel = pixels.getPixel(x, y);
        final bit = 7 - (x & 7);
        final byte = x >> 3;

        for (var plane = 0; plane < depth; plane++) {
          final offset =
              interleaved
                  ? y * rowStride + plane * bpr + byte
                  : plane * planeStride + y * bpr + byte;

          if ((pixel & (1 << plane)) != 0) {
            data[offset] |= 1 << bit;
          }
        }
      }
    }

    return bitmap;
  }

  @override
  String toString() =>
      "Bitmap: $width x $height x $depth"
      "${interleaved ? " interleaved" : ""}"
      "${bitplanes.block is Data ? " data" : ""}";
}
