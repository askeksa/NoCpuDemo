import 'dart:io';

import 'package:no_cpu/no_cpu.dart';

main(List<String> args) {
  var image = IlbmImage.fromFile(args[0]);
  var bitmap = Bitmap.fromIlbm(image);
  var palette = Palette.fromIlbm(image);

  Copper copper =
      Copper(isPrimary: true, origin: "Show")
        ..data.address = 0x00_0000
        ..useInFrame(-1);
  copper.move(DIWSTRT, 0x2C81);
  copper.move(DIWSTOP, 0x2CC1);
  copper << (Display()..setBitmap(bitmap));
  copper << palette;

  Memory m = Memory.fromRoots(0x20_0000, [copper.data]);
  File("../runner/chip.dat").writeAsBytesSync(m.build());
}
