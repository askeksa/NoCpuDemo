import 'dart:io';

import '../bin/base.dart';

main(List<String> args) {
  if (args.isEmpty) {
    print("Usage: protracker_test file.mod");
    return;
  }

  print("Module size: ${File(args[0]).lengthSync()}");
  PlayModule(args[0]).build();
}

class PlayModule extends MusicDemoBase {
  PlayModule(super.filename) : super.withProtrackerFile();
}
