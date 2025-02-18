import 'package:collection/equality.dart';
import 'package:no_cpu/music.dart';
import 'package:no_cpu/protracker.dart';

const int _rowsPerPattern = 64;

// The current playback state for one channel
class ProtrackerPlayerChannelState {
  ProtrackerInstrument? instrument;
  int period = 0;
}

// "Plays" a ProtrackerModule by generating a Music object.
class ProtrackerPlayer {
  final ProtrackerModule _module;
  final List<ProtrackerPatternEvents> _channelEvents;
  final List<ProtrackerPlayerChannelState> _channelState;

  int _restart = 0;
  int speed = 6;

  ProtrackerPlayer(this._module)
      : _channelEvents = List.generate(
            _module.totalChannels, (_) => ProtrackerPatternEvents()),
        _channelState = List.generate(
            _module.totalChannels, (_) => ProtrackerPlayerChannelState());

  Music toMusic() {
    _unroll();

    var music = Music()
      ..instruments = _module.instruments
      ..restart = _restart;

    var totalRows = _channelEvents[0].length;
    for (var row = 0; row < totalRows; row++) {
      var events = _channelEvents.map((channel) => channel.events[row]);

      music.frames.addAll(_playRow(events));
    }

    return music;
  }

  MusicFrame _handleEffects(
      Iterable<ProtrackerEvent> events,
      MusicFrameChannel Function(ProtrackerPlayerChannelState, ProtrackerEvent)
          fn) {
    var frame = MusicFrame();

    for (var (i, event) in events.indexed) {
      var channel = _channelState[i];
      var frameChannel = fn(channel, event);

      if (frameChannel.period != null) {
        frameChannel.period = frameChannel.period!.clamp(113, 856);
        channel.period = frameChannel.period!;
      }
      frame.channels.add(frameChannel);
    }

    return frame;
  }

  MusicFrame _playSubstep0(Iterable<ProtrackerEvent> events) {
    return _handleEffects(events, (channel, event) {
      var frameChannel = MusicFrameChannel();

      if (event.instrument != 0) {
        channel.instrument = _module.instruments[event.instrument - 1];
        frameChannel.volume = channel.instrument?.volume;
      }

      if (event.period != null && channel.instrument != null) {
        frameChannel.trigger = InstrumentTrigger(channel.instrument!, 0);
        frameChannel.period = event.period;
      }

      switch (event.effect) {
        case 0xC:
          frameChannel.volume = event.effectParameter;
          break;
        case 0xF:
          assert(event.effectParameter < 0x20, "CIA timing not handled");
          speed = event.effectParameter;
          break;
        case 0x0:
        case 0x1:
        case 0x2:
        case 0x3:
          // Ignore, not handled at substep 0
          break;
        default:
          assert(false, "Effect ${event.effect} not handled");
          break;
      }

      return frameChannel;
    });
  }

  MusicFrame _playSubstep(Iterable<ProtrackerEvent> events, int subStep) {
    return _handleEffects(events, (channel, event) {
      var frameChannel = MusicFrameChannel();

      switch (event.effect) {
        case 0x1:
          frameChannel.period = channel.period - event.effectParameter;
          break;
        case 0x2:
          frameChannel.period = channel.period + event.effectParameter;
          break;
        case 0x3:
          break;
        case 0x0:
        case 0xC:
        case 0xF:
          // Ignore, not relevant these substeps
          break;
        default:
          assert(false, "Effect ${event.effect} not handled");
          break;
      }

      return frameChannel;
    });
  }

  List<MusicFrame> _playRow(Iterable<ProtrackerEvent> events) {
    List<MusicFrame> frames = [];

    frames.add(_playSubstep0(events));

    for (var subStep = 1; subStep < speed; subStep++) {
      frames.add(_playSubstep(events, subStep));
    }

    return frames;
  }

  List<ProtrackerPatternEvents> _unroll() {
    var sequencePosition = 0;
    var row = 0;
    var songEnded = false;

    while (sequencePosition < _module.patternSequence.length && !songEnded) {
      while (row < _rowsPerPattern) {
        var doBreak = false;
        var breakRow = 0;
        var pattern =
            _module.patterns[_module.patternSequence[sequencePosition]];

        for (var i = 0; i < _module.totalChannels; i++) {
          var event = pattern.channels[i].events[row];
          switch (event.effect) {
            case 0xB:
              // Position jump

              if (event.effectParameter < sequencePosition) {
                // We're jumping backwards in the song, assume it's a repeat
                // and thus the end of the song
                _restart = event.effectParameter;
                songEnded = true;
              }

              // -1 because it is incremented later
              sequencePosition = event.effectParameter - 1;
              breakRow = 0;
              doBreak = true;
              event = ProtrackerEvent.noEffect(event);
              break;
            case 0xD:
              // Pattern break
              breakRow = (event.effectParameter >> 4 & 0x0F) * 10 +
                  (event.effectParameter & 0x0F);
              doBreak = true;
              event = ProtrackerEvent.noEffect(event);
              break;
          }
          _channelEvents[i].addEvent(event);
        }

        ++row;

        if (doBreak) {
          row = breakRow;
          sequencePosition++;
        }
      }
      sequencePosition++;
      row = 0;
    }

    return _channelEvents;
  }
}
