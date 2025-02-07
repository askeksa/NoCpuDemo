import 'copper.dart';
import 'memory.dart';

class Music {
  List<Instrument> instruments = [];

  /// Events happening at each frame throughout the music.
  List<MusicFrame> frames = [];

  /// Frame the music jumps to when it reaches the end,
  /// or `null` if the music doesn't loop.
  int? restart;

  /// Returns the frame at which the given [position] and [row] starts playing.
  int getTimestamp(int position, int row) {
    // TODO
    return 0;
  }
}

class Instrument {
  /// Sample data.
  Data data;

  /// Repeat posision. Always even.
  int repeat;

  /// Repeat length. Always even.
  int replen;

  // Instrument volume and finetune are not needed in the result.

  Instrument(this.data, this.repeat, this.replen);

  int get length => data.size;
}

class MusicFrame implements CopperComponent {
  /// Events in each of the four channels.
  List<MusicFrameChannel> channels = [];

  /// DMA mask for the triggered channels.
  int get triggerMask {
    int mask = 0;
    for (int i = 0; i < channels.length; i++) {
      if (channels[i].trigger != null) {
        mask |= 1 << i;
      }
    }
    return mask;
  }

  @override
  void addToCopper(Copper copper) {
    // TODO
  }
}

class MusicFrameChannel {
  /// Instrument triggered at this frame, if any.
  InstrumentTrigger? trigger;

  /// Period value to set, or `null` to keep the current value.
  /// Always non-null if [trigger] is non-null.
  int? period;

  /// Volume value to set, or `null` to keep the current value.
  int? volume;
}

class InstrumentTrigger {
  /// Instrument to trigger.
  Instrument instrument;

  /// Offset in the instrument to start playing at. Always even.
  int offset;

  InstrumentTrigger(this.instrument, [this.offset = 0]);
}
