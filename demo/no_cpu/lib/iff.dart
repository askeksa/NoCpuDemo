import 'dart:io';
import 'dart:typed_data';

class IlbmData {
  int width;
  int height;
  int bitplanes;
  Uint8List? imageData;
  Uint8List? colorMapData;

  IlbmData({
    required this.width,
    required this.height,
    required this.bitplanes,
    this.imageData,
    this.colorMapData,
  });
}

IlbmData readIlbm(String filePath) {
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

  return IlbmData(
    width: width,
    height: height,
    bitplanes: bitplanes,
    imageData: imageData,
    colorMapData: colorMapData,
  );
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
