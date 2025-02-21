import 'copper.dart';
import 'custom.dart';
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

  /// Repeat position. Always even.
  int repeat;

  /// Repeat length. Always even.
  int replen;

  // Instrument volume and finetune are not needed in the result.

  Instrument(this.data, this.repeat, this.replen);

  // Sample length in bytes. Always even.
  int get length => data.size;
}

/// Audio events for a frame. Must be called as the very first thing in the
/// frame copperlist in order for the DMA wait to work correctly.
class MusicFrame implements CopperComponent {
  /// Events in each of the four channels.
  List<MusicFrameChannel> channels = [];

  /// DMA mask for the triggered channels.
  int get triggerMask {
    int mask = 0;
    for (int i = 0; i < channels.length; i++) {
      var trigger = channels[i].trigger;
      if (trigger != null && trigger.offset != null) {
        mask |= 1 << i;
      }
    }
    return mask;
  }

  @override
  void addToCopper(Copper copper) {
    int dmaMask = triggerMask;

    if (dmaMask != 0) {
      // DMA off
      copper.move(DMACON, dmaMask);

      // Set new pointers and lengths.
      for (int i = 0; i < channels.length; i++) {
        var trigger = channels[i].trigger;
        if (trigger != null && trigger.offset != null) {
          int length =
              trigger.length ?? trigger.instrument.length - trigger.offset!;
          copper.ptr(
              AUDxLC[i], trigger.instrument.data.label + trigger.offset!);
          copper.move(AUDxLEN[i], length >> 1);
        }
      }

      // Wait for DMA off to take effect.
      copper.wait(v: 7, h: 0xB5);
    }

    // Set periods and volumes.
    for (int i = 0; i < channels.length; i++) {
      var channel = channels[i];
      if (channel.period != null) copper.move(AUDxPER[i], channel.period!);
      if (channel.volume != null) copper.move(AUDxVOL[i], channel.volume!);
    }

    if (dmaMask != 0) {
      // DMA on
      copper.move(DMACON, 0x8000 | dmaMask);

      // Wait until after the audio DMA slots on the next scanline to make sure
      // the audio subsystem has internalized the new pointers and lengths.
      copper.wait(v: 8, h: 0x17);
    }

    // Set pointers and lengths for the sample loops.
    for (int i = 0; i < channels.length; i++) {
      var trigger = channels[i].trigger;
      if (trigger != null) {
        copper.ptr(AUDxLC[i],
            trigger.instrument.data.label + trigger.instrument.repeat);
        copper.move(AUDxLEN[i], trigger.instrument.replen >> 1);
      }
    }
  }
}

class MusicFrameChannel {
  /// Instrument triggered at this frame, if any.
  InstrumentTrigger? trigger;

  /// Period value to set, or `null` to keep the current value.
  int? period;

  /// Volume value to set, or `null` to keep the current value.
  int? volume;
}

class InstrumentTrigger {
  /// Instrument to trigger.
  Instrument instrument;

  /// Offset in the instrument to start playing at. Always even.
  /// If `null`, the instrument is not triggered, but the playing sample loop
  /// is changed to the new instrument.
  int? offset;

  /// Length to play. Always even.
  /// If `null`, the play region stretches to the end of the sample.
  int? length;

  InstrumentTrigger(this.instrument, [this.offset = 0, this.length]);
}
