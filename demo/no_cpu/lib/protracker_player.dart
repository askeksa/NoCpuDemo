import 'dart:math';
import 'package:no_cpu/music.dart';
import 'package:no_cpu/protracker.dart';

// The current playback state for one channel
class ProtrackerPlayerChannelState {
  ProtrackerInstrument? instrument;
  int period = 0;
  int volume = 0;
  int portamentoTarget = 0;
  int portamentoSpeed = 0;
  int vibratoSpeed = 0;
  int vibratoDepth = 0;
  int vibratoPosition = 0; // 0-255
}

// "Plays" a ProtrackerModule by generating a Music object.
class ProtrackerPlayer {
  final ProtrackerModule _module;
  final List<ProtrackerPatternEvents> _channelEvents;
  final List<ProtrackerPlayerChannelState> _channelState;

  int _restart = 0;
  int _speed = 6;
  int _patternDelay = 0;

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

  void _performVibrato(
      ProtrackerPlayerChannelState channel, MusicFrameChannel frameChannel) {
    var index = channel.vibratoPosition & 0x1F;
    var amount = (_vibratoTable[index] * channel.vibratoDepth) >> 7;
    if (channel.vibratoPosition >= 32) {
      amount = -amount;
    }

    channel.period = frameChannel.period = channel.period + amount;
    channel.vibratoPosition =
        (channel.vibratoPosition + channel.vibratoSpeed) & 0x3F;
  }

  void _performVolumeSlide(ProtrackerPlayerChannelState channel,
      MusicFrameChannel frameChannel, ProtrackerEvent event) {
    if (event.effectParameter & 0xF0 != 0) {
      channel.volume = frameChannel.volume =
          (channel.volume + (event.effectParameter >> 4)).clampVolume();
    } else if (event.effectParameter & 0x0F != 0) {
      channel.volume = frameChannel.volume =
          (channel.volume - (event.effectParameter & 0x0F)).clampVolume();
    }
  }

  void _performPortamento(
      ProtrackerPlayerChannelState channel, MusicFrameChannel frameChannel) {
    if (channel.portamentoTarget > channel.period) {
      channel.period = frameChannel.period = min(
          channel.period + channel.portamentoSpeed, channel.portamentoTarget);
    } else if (channel.portamentoTarget < channel.period) {
      channel.period = frameChannel.period = max(
          channel.period - channel.portamentoSpeed, channel.portamentoTarget);
    }
  }

  MusicFrame _handleEffects(
      Iterable<ProtrackerEvent> events,
      MusicFrameChannel Function(ProtrackerPlayerChannelState, ProtrackerEvent)
          fn) {
    var frame = MusicFrame();

    for (var (i, event) in events.indexed) {
      var channel = _channelState[i];
      var frameChannel = fn(channel, event);

      frame.channels.add(frameChannel);
    }

    return frame;
  }

  MusicFrame _playSubstep0(Iterable<ProtrackerEvent> events) {
    return _handleEffects(events, (channel, event) {
      var frameChannel = MusicFrameChannel();
      var isPortamento = event.effect == 3 || event.effect == 5;

      if (event.instrument != 0) {
        channel.instrument = _module.instruments[event.instrument - 1];
        channel.volume = frameChannel.volume = channel.instrument!.volume;
      }

      if (event.period != null && channel.instrument != null && !isPortamento) {
        frameChannel.trigger = InstrumentTrigger(channel.instrument!, 0);
        channel.period = frameChannel.period = event.period!;
      }

      switch (event.effect) {
        case 0x3:
          if (event.period != null) {
            channel.portamentoTarget = event.period!;
          }
          if (event.effectParameter != 0) {
            channel.portamentoSpeed = event.effectParameter;
          }
        case 0x4:
          if (event.effectParameter & 0xF0 != 0) {
            channel.vibratoSpeed = event.effectParameter >> 4;
          }
          if (event.effectParameter & 0x0F != 0) {
            channel.vibratoDepth = event.effectParameter & 0x0F;
          }
        case 0x5:
          if (event.period != null) {
            channel.portamentoTarget = event.period!;
          }
        case 0xC:
          channel.volume = frameChannel.volume = event.effectParameter;
        case 0xE1:
          channel.period = frameChannel.period =
              (channel.period - event.effectParameter).clampSlidePeriod();
        case 0xE2:
          channel.period = frameChannel.period =
              (channel.period + event.effectParameter).clampSlidePeriod();
        case 0xEA:
          channel.volume = frameChannel.volume =
              (channel.volume + event.effectParameter).clampVolume();
        case 0xEB:
          channel.volume = frameChannel.volume =
              (channel.volume - event.effectParameter).clampVolume();
        case 0xEE:
          if (_patternDelay == 0) {
            _patternDelay = event.effectParameter;
          } else {
            _patternDelay--;
          }
        case 0xF:
          if (event.effectParameter >= 0x20) {
            print(
                "Warning: CIA timing not handled (wants ${event.effectParameter})");
          } else {
            _speed = event.effectParameter;
          }
        case 0x0:
        case 0x1:
        case 0x2:
        case 0x6:
        case 0xA:
          // Ignore, not handled at substep 0
          break;
        default:
          throw "Effect ${event.effect.toRadixString(16).toUpperCase()} not handled";
      }

      return frameChannel;
    });
  }

  MusicFrame _playSubstep(Iterable<ProtrackerEvent> events, int subStep) {
    return _handleEffects(events, (channel, event) {
      var frameChannel = MusicFrameChannel();

      switch (event.effect) {
        case 0x0:
          // Not implemented yet
          break;
        case 0x1:
          channel.period = frameChannel.period =
              (channel.period - event.effectParameter).clampSlidePeriod();
        case 0x2:
          channel.period = frameChannel.period =
              (channel.period + event.effectParameter).clampSlidePeriod();
        case 0x3:
          _performPortamento(channel, frameChannel);
        case 0x4:
          _performVibrato(channel, frameChannel);
        case 0x5:
          _performPortamento(channel, frameChannel);
          _performVolumeSlide(channel, frameChannel, event);
        case 0x6:
          _performVibrato(channel, frameChannel);
          _performVolumeSlide(channel, frameChannel, event);
        case 0xA:
          _performVolumeSlide(channel, frameChannel, event);
        case 0xC:
        case 0xE1:
        case 0xE2:
        case 0xEA:
        case 0xEB:
        case 0xEE:
        case 0xF:
          // Ignore, not handled on these substeps
          break;
        default:
          throw "Effect ${event.effect.toRadixString(16).toUpperCase()} not handled";
      }

      return frameChannel;
    });
  }

  List<MusicFrame> _playRow(Iterable<ProtrackerEvent> events) {
    List<MusicFrame> frames = [];

    frames.add(_playSubstep0(events));
    for (var subStep = 1; subStep < _speed; subStep++) {
      frames.add(_playSubstep(events, subStep));
    }

    while (_patternDelay-- > 0) {
      for (var subStep = 0; subStep < _speed; subStep++) {
        frames.add(_playSubstep(events, subStep));
      }
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
            case 0xD:
              // Pattern break
              breakRow = (event.effectParameter >> 4 & 0x0F) * 10 +
                  (event.effectParameter & 0x0F);
              doBreak = true;
              event = ProtrackerEvent.noEffect(event);
            case 0xE:
              // Convert Ex effects to something a little easier to handle
              var subEffect = 0xE0 | event.effectParameter >> 4;
              event = ProtrackerEvent(event.period, event.instrument, subEffect,
                  event.effectParameter & 0x0F);
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

extension AmigaClamp on int {
  int clampVolume() {
    return clamp(0, 64).toInt();
  }

  int clampSlidePeriod() {
    return clamp(113, 856).toInt();
  }
}

const int _rowsPerPattern = 64;
const List<int> _vibratoTable = [
  0,
  24,
  49,
  74,
  97,
  120,
  141,
  161,
  180,
  197,
  212,
  224,
  235,
  244,
  250,
  253,
  255,
  253,
  250,
  244,
  235,
  224,
  212,
  197,
  180,
  161,
  141,
  120,
  97,
  74,
  49,
  24
];
