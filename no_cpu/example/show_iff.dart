import 'dart:io';
import 'dart:math';

import 'package:no_cpu/no_cpu.dart';

import '../bin/base.dart' show outputFile;

main(List<String> args) {
  var image = IlbmImage.fromFile(args[0]);

  Copper copper = Copper(isPrimary: true, origin: "Show")
    ..data.address = 0x00_0000
    ..useInFrame(-1);
  copper.move(DIWSTRT, 0x2C81);
  copper.move(DIWSTOP, 0x2CC1);
  copper << (Display()..setBitmap(image.bitmap));
  copper << image.palette;

  // Show first color range if present.
  if (image.colorRanges.isNotEmpty) {
    ColorRange range = image.colorRanges[0];
    print(
      "Color range: ${range.low} - ${range.high}, "
      "rate: ${range.stepsPerSecond}, "
      "${range.isReverse ? "reverse" : "forward"}",
    );
    int step = max(1, 50 / range.stepsPerSecond).round();
    int count = range.high - range.low + 1;
    List<Copper> frames = List.generate(
      step * count,
      (i) => Copper(isPrimary: true, origin: i)..useInFrame(i),
    );
    for (int i = 0; i < step * count; i++) {
      frames[i] << (Display()..setBitmap(image.bitmap));
      if (i % step == 0) {
        frames[i] << range.step(i ~/ step);
      }
      frames[i].ptr(COP1LC, frames[(i + 1) % frames.length].label);
    }
    copper.ptr(COP1LC, frames[0].label);
  }

  Memory m = Memory.fromRoots(0x20_0000, [copper.data]);
  File(outputFile).writeAsBytesSync(m.build());

  if (args.length > 1) {
    image.save(args[1]);
  }
}
