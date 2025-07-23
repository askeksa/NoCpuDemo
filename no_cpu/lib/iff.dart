import 'dart:io';
import 'dart:typed_data';

import 'bitmap.dart';
import 'color.dart';

class ColorRange {
  /// Rate of color cycling in steps per second * 16384 / 60.
  final int rate;
  final int flags;
  final int low;
  final int high;

  late final IlbmImage image;

  ColorRange({
    required this.rate,
    required this.flags,
    required this.low,
    required this.high,
  });

  double get stepsPerSecond => rate / 16384 * 60;
  bool get isActive => (flags & 1) != 0;
  bool get isReverse => (flags & 2) != 0;

  Palette step(int i) {
    int s(int c, int i) => low + (c - low + i) % (high - low + 1);
    return Palette.fromMap({
      for (int c = low; c <= high; c++)
        if (isReverse) c: image.palette[s(c, i)] else s(c, i): image.palette[c],
    });
  }
}

class IlbmImage {
  final int width;
  final int height;
  final int bitplanes;
  final Uint8List? imageData;
  final Uint8List? colorMapData;
  final List<ColorRange> colorRanges;

  late final bitmap = Bitmap.fromIlbm(this);
  late final palette = Palette.fromIlbm(this);

  IlbmImage(
    this.width,
    this.height,
    this.bitplanes, {
    this.imageData,
    this.colorMapData,
    this.colorRanges = const [],
  }) {
    for (final crng in colorRanges) {
      crng.image = this;
    }
  }

  factory IlbmImage.fromFile(String filePath) {
    return _readIlbm(filePath);
  }

  void save(String filePath) {
    _saveIlbm(this, filePath);
  }
}

IlbmImage _readIlbm(String filePath) {
  final file = File(filePath);
  final bytes = file.readAsBytesSync();
  final byteData = ByteData.view(bytes.buffer);

  // Helper function to read a string from the byte data
  String readString(int offset, int length) {
    final chars = <int>[];
    for (var i = 0; i < length; i++) {
      chars.add(byteData.getUint8(offset + i));
    }
    return String.fromCharCodes(chars);
  }

  // Helper function to read a 4-byte ID
  String readId(int offset) {
    return readString(offset, 4);
  }

  // Read the FORM header
  if (readId(0) != 'FORM') {
    throw Exception('Not an IFF file');
  }

  // Read the FORM type
  if (readId(8) != 'ILBM') {
    throw Exception('Not an ILBM file');
  }

  int offset = 12;
  int width = 0;
  int height = 0;
  int bitplanes = 0;
  Uint8List? imageData;
  Uint8List? colorMapData;
  List<ColorRange> colorRanges = [];
  int compression = 0;

  while (offset < bytes.length) {
    String chunkId = readId(offset);
    int chunkSize = byteData.getUint32(offset + 4);

    if (chunkId == 'BMHD') {
      width = byteData.getUint16(offset + 8);
      height = byteData.getUint16(offset + 10);
      bitplanes = byteData.getUint8(offset + 16);
      compression = byteData.getUint8(offset + 18); // Read compression flag
    } else if (chunkId == 'CMAP') {
      colorMapData = bytes.sublist(offset + 8, offset + 8 + chunkSize);
    } else if (chunkId == 'CRNG') {
      // Read CRNG chunk for color cycling
      int crngOffset = offset + 8;
      int rate = byteData.getUint16(crngOffset + 2);
      int flags = byteData.getUint16(crngOffset + 4);
      int low = byteData.getUint8(crngOffset + 6);
      int high = byteData.getUint8(crngOffset + 7);

      colorRanges.add(
        ColorRange(rate: rate, flags: flags, low: low, high: high),
      );
    } else if (chunkId == 'BODY') {
      imageData = bytes.sublist(offset + 8, offset + 8 + chunkSize);

      // Decompress if compression is enabled (1 = byte run encoding)
      if (compression == 1) {
        imageData = _decompressByteRun1(imageData);
      }
    }

    offset += 8 + chunkSize;
    // Chunk sizes are padded to even numbers
    if (chunkSize % 2 != 0) {
      offset++;
    }
  }

  if (width == 0 || height == 0 || imageData == null) {
    throw Exception('Incomplete ILBM data');
  }

  return IlbmImage(
    width,
    height,
    bitplanes,
    imageData: imageData,
    colorMapData: colorMapData,
    colorRanges: colorRanges,
  );
}

void _saveIlbm(IlbmImage image, String filePath) {
  final chunks = <Uint8List>[];

  // BMHD chunk
  final bmhdData = ByteData(20);
  bmhdData.setUint16(0, image.width);
  bmhdData.setUint16(2, image.height);
  bmhdData.setInt16(4, 0); // x
  bmhdData.setInt16(6, 0); // y
  bmhdData.setUint8(8, image.bitplanes);
  bmhdData.setUint8(9, 0); // masking
  bmhdData.setUint8(10, 0); // no compression
  bmhdData.setUint8(11, 0); // pad1
  bmhdData.setUint16(12, 0); // transparentColor
  bmhdData.setUint8(14, 10); // xAspect
  bmhdData.setUint8(15, 11); // yAspect
  bmhdData.setInt16(16, image.width); // pageWidth
  bmhdData.setInt16(18, image.height); // pageHeight
  chunks.add(_createChunk('BMHD', bmhdData.buffer.asUint8List()));

  // CMAP chunk
  if (image.colorMapData != null) {
    chunks.add(_createChunk('CMAP', image.colorMapData!));
  }

  // CRNG chunks
  for (final crng in image.colorRanges) {
    final crngData = ByteData(8);
    crngData.setInt16(0, 0); // pad1
    crngData.setInt16(2, crng.rate);
    crngData.setInt16(4, crng.flags);
    crngData.setUint8(6, crng.low);
    crngData.setUint8(7, crng.high);
    chunks.add(_createChunk('CRNG', crngData.buffer.asUint8List()));
  }

  // BODY chunk
  if (image.imageData != null) {
    chunks.add(_createChunk('BODY', image.imageData!));
  }

  // Calculate total size for FORM header
  int totalSize = 4; // for 'ILBM'
  for (final chunk in chunks) {
    totalSize += chunk.length;
  }

  // Create the final file buffer
  final builder = BytesBuilder();
  final headerData = ByteData(12);
  headerData.setUint32(0, 0x464F524D); // 'FORM'
  headerData.setUint32(4, totalSize);
  headerData.setUint32(8, 0x494C424D); // 'ILBM'
  builder.add(headerData.buffer.asUint8List());

  for (final chunk in chunks) {
    builder.add(chunk);
  }

  File(filePath).writeAsBytesSync(builder.toBytes());
}

Uint8List _createChunk(String id, Uint8List data) {
  final builder = BytesBuilder();
  final chunkHeader = ByteData(8);
  final idCodes = id.codeUnits;
  chunkHeader.setUint8(0, idCodes[0]);
  chunkHeader.setUint8(1, idCodes[1]);
  chunkHeader.setUint8(2, idCodes[2]);
  chunkHeader.setUint8(3, idCodes[3]);
  chunkHeader.setUint32(4, data.length);

  builder.add(chunkHeader.buffer.asUint8List());
  builder.add(data);

  // Pad to even length
  if (data.length % 2 != 0) {
    builder.addByte(0);
  }

  return builder.toBytes();
}

// ByteRun1 decompression algorithm
Uint8List _decompressByteRun1(Uint8List compressedData) {
  List<int> decompressedData = [];
  int i = 0;

  while (i < compressedData.length) {
    int n = compressedData[i++];

    if (n < 128) {
      // Copy the next n+1 bytes literally
      for (int j = 0; j < n + 1; j++) {
        decompressedData.add(compressedData[i++]);
      }
    } else if (n > 128) {
      // Replicate the next byte -n+1 times
      int byteToReplicate = compressedData[i++];
      for (int j = 0; j < 257 - n; j++) {
        decompressedData.add(byteToReplicate);
      }
    } else if (n == 128) {
      // No operation
    }
  }

  return Uint8List.fromList(decompressedData);
}
