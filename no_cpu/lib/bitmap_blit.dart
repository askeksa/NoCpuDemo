import 'bitmap.dart';
import 'blitter.dart';
import 'memory.dart';

/// Helpers for setting pointers, strides, size (optional, defaults to `true`)
/// and masks (optional, defaults to `true` if the A channel is involved) from
/// a bitmap.
///
/// If the width or height is already set, these methods will assert that the
/// new values match the existing ones.
///
/// Note that these do NOT set shifts.
extension SetBitmaps on Blit {
  Label _setBitplane(
    Bitmap bitmap,
    int plane,
    int x,
    int y,
    int? w,
    int? h,
    bool size,
    bool mask,
  ) {
    w ??= bitmap.width - x;
    h ??= bitmap.height - y;
    int lastx = x + w - 1;
    int xword = x >> 4;
    int lastxword = lastx >> 4;

    if (size) {
      int width = lastxword - xword + 1;
      int height = h;
      if (this.width != null && this.width != width) {
        throw Exception("Mismatching width");
      }
      if (this.height != null && this.height != height) {
        throw Exception("Mismatching height");
      }
      this.width = width;
      this.height = height;
    }

    if (mask) {
      aFWM = 0xFFFF >> (x & 15);
      aLWM = 0xFFFF << (15 - (lastx & 15));
    }

    return bitmap.bitplanes +
        plane * bitmap.planeStride +
        y * bitmap.rowStride +
        xword * 2;
  }

  void aSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    aPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    aStride = bitmap.rowStride;
  }

  void bSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    bPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    bStride = bitmap.rowStride;
  }

  void cSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    cPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    cStride = bitmap.rowStride;
  }

  void dSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    dPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    dStride = bitmap.rowStride;
  }

  void abSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    abPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    abStride = bitmap.rowStride;
  }

  void acSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    acPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    acStride = bitmap.rowStride;
  }

  void adSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    adPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    adStride = bitmap.rowStride;
  }

  void bcSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    bcPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    bcStride = bitmap.rowStride;
  }

  void bdSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    bdPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    bdStride = bitmap.rowStride;
  }

  void cdSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    cdPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    cdStride = bitmap.rowStride;
  }

  void abcSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    abcPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    abcStride = bitmap.rowStride;
  }

  void abdSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    abdPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    abdStride = bitmap.rowStride;
  }

  void acdSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    acdPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    acdStride = bitmap.rowStride;
  }

  void bcdSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    bcdPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    bcdStride = bitmap.rowStride;
  }

  void abcdSetBitplane(
    Bitmap bitmap,
    int plane, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    abcdPtr = _setBitplane(bitmap, plane, x, y, w, h, size, mask);
    abcdStride = bitmap.rowStride;
  }

  Label _setInterleaved(
    Bitmap bitmap,
    int x,
    int y,
    int? w,
    int? h,
    bool size,
    bool mask,
  ) {
    assert(bitmap.interleaved);

    w ??= bitmap.width - x;
    h ??= bitmap.height - y;
    int lastx = x + w - 1;
    int xword = x >> 4;
    int lastxword = lastx >> 4;

    if (size) {
      int width = lastxword - xword + 1;
      int height = h * bitmap.depth;
      if (this.width != null && this.width != width) {
        throw Exception("Mismatching width");
      }
      if (this.height != null && this.height != height) {
        throw Exception("Mismatching height");
      }
      this.width = width;
      this.height = height;
    }

    if (mask) {
      aFWM = 0xFFFF >> (x & 15);
      aLWM = 0xFFFF << (15 - (lastx & 15));
    }

    return bitmap.bitplanes + y * bitmap.rowStride + xword * 2;
  }

  void aSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    aPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    aStride = bitmap.planeStride;
  }

  void bSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    bPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    bStride = bitmap.planeStride;
  }

  void cSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    cPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    cStride = bitmap.planeStride;
  }

  void dSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    dPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    dStride = bitmap.planeStride;
  }

  void abSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    abPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    abStride = bitmap.planeStride;
  }

  void acSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    acPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    acStride = bitmap.planeStride;
  }

  void adSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    adPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    adStride = bitmap.planeStride;
  }

  void bcSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    bcPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    bcStride = bitmap.planeStride;
  }

  void bdSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    bdPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    bdStride = bitmap.planeStride;
  }

  void cdSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    cdPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    cdStride = bitmap.planeStride;
  }

  void abcSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    abcPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    abcStride = bitmap.planeStride;
  }

  void abdSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    abdPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    abdStride = bitmap.planeStride;
  }

  void acdSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    acdPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    acdStride = bitmap.planeStride;
  }

  void bcdSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = false,
  }) {
    bcdPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    bcdStride = bitmap.planeStride;
  }

  void abcdSetInterleaved(
    Bitmap bitmap, {
    int x = 0,
    int y = 0,
    int? w,
    int? h,
    bool size = true,
    bool mask = true,
  }) {
    abcdPtr = _setInterleaved(bitmap, x, y, w, h, size, mask);
    abcdStride = bitmap.planeStride;
  }
}
