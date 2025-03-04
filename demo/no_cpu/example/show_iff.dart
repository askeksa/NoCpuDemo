import 'dart:io';

import 'package:no_cpu/bitmap.dart';
import 'package:no_cpu/color.dart';
import 'package:no_cpu/copper.dart';
import 'package:no_cpu/custom.dart';
import 'package:no_cpu/display.dart';
import 'package:no_cpu/iff.dart';
import 'package:no_cpu/memory.dart';

main(List<String> args) {
  var image = readIlbm(args[0]);
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
