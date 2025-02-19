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
  int offset = 0;
  bool useOffset = false;
}

// "Plays" a ProtrackerModule by generating a Music object.
class ProtrackerPlayer {
  final ProtrackerModule _module;
  final List<ProtrackerPatternEvents> _channelEvents;
  final List<ProtrackerPlayerChannelState> _channelState;

  int _restart = 0;
  int _speed = 6;
  int _bpm = 125;
  int _bpmCount = 125;
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

    music.frames.addAll(_bpmFrames());
    return music;
  }

  void _performVibrato(
      ProtrackerPlayerChannelState channel, MusicFrameChannel frameChannel) {
    var index = channel.vibratoPosition & 0x1F;
    var amount = (_vibratoTable[index] * channel.vibratoDepth) >> 7;
    if (channel.vibratoPosition >= 0x20) {
      amount = -amount;
    }

    frameChannel.period = channel.period + amount;
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

  MusicFrameChannel _performInstrumentTrigger(
      ProtrackerPlayerChannelState channel, ProtrackerEvent event) {
    var frameChannel = MusicFrameChannel();
    var isPortamento = event.effect == 3 || event.effect == 5;
    if (event.instrument != 0) {
      channel.instrument = _module.instruments[event.instrument - 1];
      channel.volume = frameChannel.volume = channel.instrument!.volume;
      channel.useOffset = false;
    }

    if (event.period != null && channel.instrument != null && !isPortamento) {
      frameChannel.trigger = InstrumentTrigger(channel.instrument!);
      channel.period = frameChannel.period = event.period!;
    }

    return frameChannel;
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
      var frameChannel = _performInstrumentTrigger(channel, event);

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
        case 0x9:
          if (event.effectParameter != 0) {
            channel.offset = event.effectParameter * 256;
          }
          channel.useOffset = true;
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
        case 0xED:
          if (event.effectParameter > 0) {
            // Cancel the instrument trigger on note delay
            frameChannel = MusicFrameChannel();
          }
        case 0xEE:
          if (_patternDelay == 0) {
            _patternDelay = event.effectParameter;
          }
        case 0xF:
          if (event.effectParameter >= 0x20) {
            _bpm = event.effectParameter;
            print("Warning: Fake CIA timing ${event.effectParameter} active");
          } else {
            _speed = event.effectParameter;
          }
        case 0x0:
        case 0x1:
        case 0x2:
        case 0x6:
        case 0xA:
        case 0xEC:
          // Ignore, not handled at substep 0
          break;
        default:
          throw "Effect ${event.effect.toRadixString(16).toUpperCase()} not handled";
      }

      if (channel.useOffset) {
        frameChannel.trigger?.offset = channel.offset;
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
        case 0xEC:
          if (subStep == event.effectParameter) {
            frameChannel.volume = 0;
          }
        case 0xED:
          if (subStep == event.effectParameter) {
            frameChannel = _performInstrumentTrigger(channel, event);
          }
        case 0x9:
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

  Iterable<MusicFrame> _rowFrames(Iterable<ProtrackerEvent> events) sync* {
    yield _playSubstep0(events);
    for (var subStep = 1; subStep < _speed; subStep++) {
      yield _playSubstep(events, subStep);
    }

    while (_patternDelay > 0) {
      _patternDelay--;
      for (var subStep = 0; subStep < _speed; subStep++) {
        yield _playSubstep(events, subStep);
      }
    }
  }

  Iterable<MusicFrame> _songFrames() sync* {
    var totalRows = _channelEvents[0].length;
    for (var row = 0; row < totalRows; row++) {
      var events = _channelEvents.map((channel) => channel.events[row]);
      yield* _rowFrames(events);
    }
  }

  Iterable<MusicFrame> _bpmFrames() sync* {
    var it = _songFrames().iterator;

    while (true) {
      var frame = MusicFrame()
        ..channels =
            List.generate(_module.totalChannels, (_) => MusicFrameChannel());

      if (_bpmCount < 125) {
        _bpmCount += _bpm;
        yield frame;
      } else {
        while (_bpmCount >= 125) {
          if (!it.moveNext()) {
            return;
          }

          _bpmCount -= 125;

          var newFrame = it.current;
          for (var (i, newChannel) in newFrame.channels.indexed) {
            var oldChannel = frame.channels[i];
            if (newChannel.period != null) {
              oldChannel.period = newChannel.period;
            }
            if (newChannel.trigger != null) {
              oldChannel.trigger = newChannel.trigger;
            }
            if (newChannel.volume != null) {
              oldChannel.volume = newChannel.volume;
            }
          }
        }
        _bpmCount += _bpm;

        yield frame;
      }
    }
  }

  List<ProtrackerPatternEvents> _unroll() {
    var sequencePosition = 0;
    var row = 0;
    var songEnded = false;
    var loopPoints = List.filled(4, 0);
    var loopCounters = List.filled(4, 0);

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
              var subParameter = event.effectParameter & 0x0F;

              if (subEffect == 0xE6) {
                // Loop
                if (subParameter == 0) {
                  loopPoints[i] = row;
                } else {
                  if (loopCounters[i] == 1) {
                    // Loop done
                    loopCounters[i] = 0;
                    loopPoints[i] = 0;
                  } else {
                    if (loopCounters[i]-- == 0) {
                      // First loop
                      loopCounters[i] = subParameter;
                    }
                    breakRow = loopPoints[i];
                    sequencePosition--; // Cancel later increment
                    doBreak = true;
                  }
                }
                event = ProtrackerEvent(event.period, event.instrument, 0, 0);
              } else {
                event = ProtrackerEvent(
                    event.period, event.instrument, subEffect, subParameter);
              }
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
