import 'dart:io';
import 'dart:typed_data';

import 'iff.dart';
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

  factory ChunkyPixels.fromFile(String filePath, int width, int height) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();

    assert(
      bytes.length == width * height,
      "Invalid file size for ChunkyPixels: ${bytes.length}, expected ${width * height}",
    );

    return ChunkyPixels(width, height)..pixels.setAll(0, bytes);
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
    Mutability mutability = Mutability.immutable,
  }) {
    bytesPerRow = bytesPerRowFor(width, alignment);
    bitplanes = Data.blank(
      sizeInBytes,
      alignment: alignment,
      singlePage: singlePage,
      mutability: mutability,
      origin: this,
    ).label;
  }

  factory Bitmap.fromChunky(
    ChunkyPixels pixels, {
    int depth = 8,
    int alignment = 3,
    bool interleaved = false,
    bool singlePage = false,
    Mutability mutability = Mutability.immutable,
  }) {
    var bitmap = Bitmap.blank(
      pixels.width,
      pixels.height,
      depth,
      alignment: alignment,
      interleaved: interleaved,
      singlePage: singlePage,
      mutability: mutability,
    );

    return bitmap..chunky2planar(pixels);
  }

  void fill(int Function(int x, int y) generator) {
    chunky2planar(ChunkyPixels.generate(width, height, generator));
  }

  void chunky2planar(ChunkyPixels pixels) {
    final data = Uint8List.view(
      (bitplanes.block as Data).bytes.buffer,
      bitplanes.offsetInBlock,
    );

    for (var y = 0; y < pixels.height; y++) {
      for (var x = 0; x < pixels.width; x++) {
        final pixel = pixels.getPixel(x, y);
        final bit = 7 - (x & 7);
        final byte = x >> 3;

        for (var plane = 0; plane < depth; plane++) {
          final offset = plane * planeStride + y * rowStride + byte;

          if ((pixel & (1 << plane)) != 0) {
            data[offset] |= 1 << bit;
          } else {
            data[offset] &= ~(1 << bit);
          }
        }
      }
    }
  }

  factory Bitmap.generate(
    int width,
    int height,
    int Function(int x, int y) generator, {
    int depth = 8,
    int alignment = 3,
    bool interleaved = false,
    bool singlePage = false,
    Mutability mutability = Mutability.immutable,
  }) {
    return Bitmap.fromChunky(
      ChunkyPixels.generate(width, height, generator),
      depth: depth,
      alignment: alignment,
      interleaved: interleaved,
      singlePage: singlePage,
      mutability: mutability,
    );
  }

  factory Bitmap.fromIlbm(
    IlbmImage ilbm, {
    Mutability mutability = Mutability.immutable,
  }) {
    if (ilbm.imageData == null) {
      throw ArgumentError("ILBM data does not contain image data");
    }

    int paddedWidth = (ilbm.width + 15) & ~15;
    int alignment = 1;
    while ((paddedWidth >> (alignment + 3)) & 1 == 0) {
      alignment++;
    }

    var bitmap = Bitmap.blank(
      ilbm.width,
      ilbm.height,
      ilbm.bitplanes,
      alignment: alignment,
      interleaved: true,
      mutability: mutability,
    );

    final data = (bitmap.bitplanes.block as Data).bytes;
    assert(data.length == ilbm.imageData!.length);
    data.setAll(0, ilbm.imageData!);

    return bitmap;
  }

  int getPlanePixel(int x, int y, int plane) {
    final data = (bitplanes.block as Data).bytes;

    final offset =
        bitplanes.offsetInBlock +
        y * rowStride +
        plane * planeStride +
        (x >> 3);

    final byte = data[offset];
    final bit = 7 - (x & 7);
    return (byte >> bit) & 1;
  }

  int getPixel(int x, int y) {
    int value = 0;
    for (int plane = 0; plane < depth; plane++) {
      value |= getPlanePixel(x, y, plane) << plane;
    }
    return value;
  }

  void setPlanePixel(int x, int y, int plane, int value) {
    final data = (bitplanes.block as Data).bytes;

    final offset =
        bitplanes.offsetInBlock +
        y * rowStride +
        plane * planeStride +
        (x >> 3);

    final bit = 7 - (x & 7);
    if ((value & 1) == 0) {
      data[offset] &= ~(1 << bit);
    } else {
      data[offset] |= (1 << bit);
    }
  }

  void setPixel(int x, int y, int value) {
    for (int plane = 0; plane < depth; plane++) {
      setPlanePixel(x, y, plane, (value >> plane) & 1);
    }
  }

  Bitmap transform(
    int Function(int x, int y, int pixel) transformer, {
    int? depth,
    bool? interleaved,
    Mutability mutability = Mutability.immutable,
  }) {
    return Bitmap.generate(
      width,
      height,
      (x, y) => transformer(x, y, getPixel(x, y)),
      depth: depth ?? this.depth,
      alignment: alignment,
      interleaved: interleaved ?? this.interleaved,
      mutability: mutability,
    );
  }

  Bitmap crop({
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    int pad = 0,
    int? depth,
    bool? interleaved,
  }) {
    depth ??= this.depth;
    interleaved ??= this.interleaved;
    w ??= width - x;
    h ??= height - y;
    return Bitmap.generate(
      w,
      h,
      (px, py) {
        px += x;
        py += y;
        return px >= 0 && px < width && py >= 0 && py < height
            ? getPixel(px, py)
            : pad;
      },
      depth: depth,
      interleaved: interleaved,
    );
  }

  (int, int, Bitmap) autocrop([
    bool Function(int x, int y, int pixel)? included,
  ]) {
    included ??= (_, _, p) => p != 0;
    int minx = width - 1;
    int maxx = 0;
    int miny = height - 1;
    int maxy = 0;
    bool found = false;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (included(x, y, getPixel(x, y))) {
          if (x < minx) minx = x;
          if (x > maxx) maxx = x;
          if (y < miny) miny = y;
          if (y > maxy) maxy = y;
          found = true;
        }
      }
    }
    if (!found) {
      throw StateError("No pixels found in bitmap for autocrop");
    }
    Bitmap image = crop(
      x: minx,
      y: miny,
      w: maxx - minx + 1,
      h: maxy - miny + 1,
    );
    return (minx, miny, image);
  }

  @override
  String toString() =>
      "Bitmap $width x $height x $depth"
      "${interleaved ? " interleaved" : ""}"
      "${bitplanes.block is Data ? " data" : ""}";
}
