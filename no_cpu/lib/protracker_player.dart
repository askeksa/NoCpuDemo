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
  int vibratoPosition = 0;
  int tremoloSpeed = 0;
  int tremoloDepth = 0;
  int tremoloPosition = 0;
  int offset = 0; // buffered 9xx offset
  int? restoreBasePeriod; // period to restore on next step
  bool useOffset = false; // this is used for handling the buffering of 9xx
}

// "Plays" a ProtrackerModule by generating a Music object.
class ProtrackerPlayer {
  final ProtrackerModule _module;
  final List<ProtrackerPlayerChannelState> _channelState;

  int _speed = 6;
  int _bpm = 125;
  int _patternDelay = 0;
  int _frameCount = 0;
  final Map<(int, int), int> _timestamps = {};

  ProtrackerPlayer(this._module)
    : _channelState = List.generate(
        _module.totalChannels,
        (_) => ProtrackerPlayerChannelState(),
      );

  Music toMusic({int hardwareBpm = 125}) {
    var unrolled = ProtrackerUnroller.unroll(_module);
    var frames = _bpmFrames(unrolled, hardwareBpm).toList();

    var music = Music()
      ..frames = frames
      ..timestamps = _timestamps
      ..instruments = _module.instruments
      ..restart = unrolled.restart != null
          ? _timestamps[unrolled.restart!]
          : null;

    return music;
  }

  void _performVibrato(
    ProtrackerPlayerChannelState channel,
    MusicFrameChannel frameChannel,
  ) {
    // TODO: Add vibrato waveforms

    var index = channel.vibratoPosition & 0x1F;
    var amount = (_vibratoTable[index] * channel.vibratoDepth) >> 7;
    if (channel.vibratoPosition >= 0x20) {
      amount = -amount;
    }

    frameChannel.period = channel.period + amount;
    channel.vibratoPosition =
        (channel.vibratoPosition + channel.vibratoSpeed) & 0x3F;
  }

  void _performTremolo(
    ProtrackerPlayerChannelState channel,
    MusicFrameChannel frameChannel,
  ) {
    // TODO: Add tremolo waveforms

    var index = channel.tremoloPosition & 0x1F;
    var amount = (_vibratoTable[index] * channel.tremoloDepth) >> 6;
    if (channel.tremoloPosition >= 0x20) {
      amount = -amount;
    }

    frameChannel.volume = (channel.volume + amount).clampVolume();
    channel.tremoloPosition =
        (channel.tremoloPosition + channel.tremoloSpeed) & 0x3F;
  }

  void _performVolumeSlide(
    ProtrackerPlayerChannelState channel,
    MusicFrameChannel frameChannel,
    ProtrackerEvent event,
  ) {
    if (event.effectParameter & 0xF0 != 0) {
      channel.volume = frameChannel.volume =
          (channel.volume + (event.effectParameter >> 4)).clampVolume();
    } else if (event.effectParameter & 0x0F != 0) {
      channel.volume = frameChannel.volume =
          (channel.volume - (event.effectParameter & 0x0F)).clampVolume();
    }
  }

  void _performPortamento(
    ProtrackerPlayerChannelState channel,
    MusicFrameChannel frameChannel,
  ) {
    if (channel.portamentoTarget != 0) {
      if (channel.portamentoTarget > channel.period) {
        channel.period = frameChannel.period = min(
          channel.period + channel.portamentoSpeed,
          channel.portamentoTarget,
        );
      } else if (channel.portamentoTarget < channel.period) {
        channel.period = frameChannel.period = max(
          channel.period - channel.portamentoSpeed,
          channel.portamentoTarget,
        );
      }
      if (channel.period == channel.portamentoTarget) {
        channel.portamentoTarget = 0;
      }
    }
  }

  MusicFrameChannel _performInstrumentTrigger(
    ProtrackerPlayerChannelState channel,
    ProtrackerEvent event,
  ) {
    var frameChannel = MusicFrameChannel();
    var isPortamento = event.effect == 3 || event.effect == 5;

    if (channel.restoreBasePeriod != 0) {
      frameChannel.period = channel.restoreBasePeriod;
      channel.restoreBasePeriod = 0;
    }

    if (event.instrument != 0) {
      channel.instrument = _module.instruments[event.instrument - 1];
      channel.volume = frameChannel.volume = channel.instrument!.volume;
      channel.useOffset = false;
      frameChannel.trigger = frameChannel.trigger = InstrumentTrigger(
        channel.instrument!,
        null,
      );
    }

    if (event.note != null && channel.instrument != null && !isPortamento) {
      frameChannel.trigger = InstrumentTrigger(channel.instrument!);
      channel.period = frameChannel.period = _noteToPeriod(
        event.note!,
        channel.instrument!.finetune,
      );

      // TODO: Add waveform retrigger control
      channel.vibratoPosition = 0;
      channel.tremoloPosition = 0;
    }

    return frameChannel;
  }

  MusicFrame _handleEffects(
    Iterable<ProtrackerEvent> events,
    MusicFrameChannel Function(ProtrackerPlayerChannelState, ProtrackerEvent)
    fn,
  ) {
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
        case 0x0:
          if (event.effectParameter != 0) {
            channel.restoreBasePeriod = channel.period;
          }
        case 0x3:
          if (event.note != null) {
            channel.portamentoTarget = _noteToPeriod(
              event.note!,
              channel.instrument?.finetune ?? 0,
            );
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
          if (event.note != null) {
            channel.portamentoTarget = _noteToPeriod(
              event.note!,
              channel.instrument?.finetune ?? 0,
            );
          }
        case 0x7:
          if (event.effectParameter & 0xF0 != 0) {
            channel.tremoloSpeed = event.effectParameter >> 4;
          }
          if (event.effectParameter & 0x0F != 0) {
            channel.tremoloDepth = event.effectParameter & 0x0F;
          }
        case 0x8:
          print("Warning: 8xx used, this is unsupported");
        case 0x9:
          if (event.effectParameter != 0) {
            channel.offset = event.effectParameter * 256;
          }
          channel.useOffset = true;
        case 0xC:
          channel.volume = frameChannel.volume = event.effectParameter
              .clampVolume();
        case 0xE0:
          print("Warning: E0x (filter control) used, this is unsupported");
          break;
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
          if (event.effectParameter >= _speed) {
            channel.restoreBasePeriod = channel.period;
          }
          if (event.effectParameter > 0) {
            // Cancel the instrument trigger on note delay (but not volume)
            frameChannel.trigger = null;
            frameChannel.period = null;
          }
        case 0xEE:
          if (_patternDelay == 0) {
            _patternDelay = event.effectParameter;
          }
        case 0xEF:
          print("Warning: EFx (funk repeat) used, this is unsupported");
        case 0xF:
          if (event.effectParameter >= 0x20) {
            _bpm = event.effectParameter;
            print("Warning: Fake CIA timing ${event.effectParameter} active");
          } else {
            _speed = event.effectParameter;
          }
        case 0x1:
        case 0x2:
        case 0x6:
        case 0xA:
        case 0xE9:
        case 0xEC:
          // Ignore, not handled at substep 0
          break;
        default:
          throw "Effect ${event.effect.toRadixString(16).toUpperCase()} not handled";
      }

      if (channel.useOffset && frameChannel.trigger != null) {
        var instrument = frameChannel.trigger!.instrument;
        if (channel.offset >= instrument.length) {
          // The offset is out of range. In this case the trigger should start
          // playing the loop.
          frameChannel.trigger?.offset = instrument.repeat;
          frameChannel.trigger?.length = instrument.replen;
        } else {
          frameChannel.trigger?.offset = channel.offset;
        }
      }

      return frameChannel;
    });
  }

  MusicFrame _playSubstep(Iterable<ProtrackerEvent> events, int subStep) {
    return _handleEffects(events, (channel, event) {
      var frameChannel = MusicFrameChannel();

      switch (event.effect) {
        case 0x0:
          if (event.effectParameter != 0) {
            int arpStep = subStep % 3;
            if (arpStep == 0) {
              frameChannel.period = channel.period;
            } else {
              var addNote = 0;
              switch (arpStep) {
                case 1:
                  addNote = event.effectParameter >> 4;
                case 2:
                  addNote = event.effectParameter & 0x0F;
              }
              var baseNote = _periodToNote(
                channel.period,
                channel.instrument?.finetune ?? 0,
              );
              frameChannel.period = _noteToPeriod(
                baseNote + addNote,
                channel.instrument?.finetune ?? 0,
              );
            }
          }
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
        case 0x7:
          _performTremolo(channel, frameChannel);
        case 0xA:
          _performVolumeSlide(channel, frameChannel, event);
          break;
        case 0xE9:
          if ((event.effectParameter < 2) ||
              (subStep % event.effectParameter == 0)) {
            frameChannel = _performInstrumentTrigger(channel, event);
          }
        case 0xEC:
          if (subStep == event.effectParameter) {
            frameChannel.volume = 0;
          }
        case 0xED:
          if (subStep == event.effectParameter) {
            frameChannel = _performInstrumentTrigger(channel, event);
          }
        case 0x8:
        case 0x9:
        case 0xC:
        case 0xE0:
        case 0xE1:
        case 0xE2:
        case 0xEA:
        case 0xEB:
        case 0xEE:
        case 0xEF:
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

  Iterable<MusicFrame> _songFrames(ProtrackerUnroller unrolled) sync* {
    var totalRows = unrolled.channelEvents[0].length;
    for (var row = 0; row < totalRows; row++) {
      _timestamps[unrolled.unrolledPositions[row]] = _frameCount;

      var events = unrolled.channelEvents.map((channel) => channel.events[row]);

      yield* _rowFrames(events);
    }
  }

  Iterable<MusicFrame> _bpmFrames(ProtrackerUnroller unrolled, int hardwareBpm) sync* {
    var bpmCount = hardwareBpm;
    var it = _songFrames(unrolled).iterator;

    _frameCount = 0;

    while (true) {
      var frame = MusicFrame()
        ..channels = List.generate(
          _module.totalChannels,
          (_) => MusicFrameChannel(),
        );

      if (bpmCount < hardwareBpm) {
        bpmCount += _bpm;
        yield frame;
      } else {
        while (bpmCount >= hardwareBpm) {
          if (!it.moveNext()) {
            return;
          }

          bpmCount -= hardwareBpm;

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
        bpmCount += _bpm;

        yield frame;
      }
      _frameCount++;
    }
  }
}

class ProtrackerUnroller {
  final ProtrackerModule module;
  final List<ProtrackerPatternEvents> channelEvents;
  final List<(int, int)> unrolledPositions = [];
  (int, int)? restart = (0, 0);

  ProtrackerUnroller.unroll(this.module)
    : channelEvents = List.generate(
        module.totalChannels,
        (_) => ProtrackerPatternEvents(),
      ) {
    _unroll();
  }

  void _unroll() {
    var sequencePosition = 0;
    var row = 0;
    var songEnded = false;
    var loopPoints = List.filled(4, 0);
    var loopCounters = List.filled(4, 0);
    var seenPositions = <(int, int)>{};

    while (sequencePosition < module.patternSequence.length && !songEnded) {
      while (row < _rowsPerPattern && !songEnded) {
        // If we have seen this row before and we're not in a loop, end the song
        if (seenPositions.contains((sequencePosition, row)) &&
            loopCounters.every((n) => n == 0)) {
          restart = (sequencePosition, row);
          songEnded = true;
          break;
        }

        var doBreak = false;
        var breakRow = 0;
        var pattern = module.patterns[module.patternSequence[sequencePosition]];

        unrolledPositions.add((sequencePosition, row));
        seenPositions.add((sequencePosition, row));

        for (var i = 0; i < module.totalChannels; i++) {
          var event = pattern.channels[i].events[row];
          switch (event.effect) {
            case 0xB:
              // Position jump

              // -1 because it is incremented later
              sequencePosition = event.effectParameter - 1;
              breakRow = 0;
              doBreak = true;
              event = ProtrackerEvent.noEffect(event);
            case 0xD:
              // Pattern break
              breakRow =
                  (event.effectParameter >> 4 & 0x0F) * 10 +
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
                event = ProtrackerEvent.noEffect(event);
              } else {
                event = ProtrackerEvent(
                  event.note,
                  event.instrument,
                  subEffect,
                  subParameter,
                );
              }
            case 0xF:
              if (event.effectParameter == 0) {
                restart = null;
                songEnded = true;
              }
              break;
          }
          channelEvents[i].addEvent(event);
        }

        row++;

        if (doBreak) {
          row = breakRow;
          sequencePosition++;
          if (sequencePosition >= module.patternSequence.length) {
            sequencePosition = 0;
            songEnded = true;
          }
        }
      }
      sequencePosition++;
      row = 0;
    }
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

const int _notesPerFinetuneSetting = 37;

int _noteToPeriod(int note, int finetune) {
  return _finetune[finetune * _notesPerFinetuneSetting + note];
}

int _periodToNote(int period, int finetune) {
  var index = finetune * _notesPerFinetuneSetting;
  for (var (i, p)
      in _finetune.sublist(index, index + _notesPerFinetuneSetting).indexed) {
    if (period >= p) {
      return i;
    }
  }

  throw "_periodToNote failed ($period not found)";
}

// dart format off
const List<int> _vibratoTable = [
    0,  24,  49,  74,  97, 120, 141, 161,
  180, 197, 212, 224, 235, 244, 250, 253,
  255, 253, 250, 244, 235, 224, 212, 197,
  180, 161, 141, 120,  97,  74,  49,  24
];

const List<int> _finetune = [
  // finetune 0
  856,808,762,720,678,640,604,570,538,508,480,453,
  428,404,381,360,339,320,302,285,269,254,240,226,
  214,202,190,180,170,160,151,143,135,127,120,113,0,

  // finetune 1
  850,802,757,715,674,637,601,567,535,505,477,450,
  425,401,379,357,337,318,300,284,268,253,239,225,
  213,201,189,179,169,159,150,142,134,126,119,113,0,

  // finetune 2
  844,796,752,709,670,632,597,563,532,502,474,447,
  422,398,376,355,335,316,298,282,266,251,237,224,
  211,199,188,177,167,158,149,141,133,125,118,112,0,

  // finetune 3
  838,791,746,704,665,628,592,559,528,498,470,444,
  419,395,373,352,332,314,296,280,264,249,235,222,
  209,198,187,176,166,157,148,140,132,125,118,111,0,

  // finetune 4
  832,785,741,699,660,623,588,555,524,495,467,441,
  416,392,370,350,330,312,294,278,262,247,233,220,
  208,196,185,175,165,156,147,139,131,124,117,110,0,

  // finetune 5
  826,779,736,694,655,619,584,551,520,491,463,437,
  413,390,368,347,328,309,292,276,260,245,232,219,
  206,195,184,174,164,155,146,138,130,123,116,109,0,

  // finetune 6
  820,774,730,689,651,614,580,547,516,487,460,434,
  410,387,365,345,325,307,290,274,258,244,230,217,
  205,193,183,172,163,154,145,137,129,122,115,109,0,

  // finetune 7
  814,768,725,684,646,610,575,543,513,484,457,431,
  407,384,363,342,323,305,288,272,256,242,228,216,
  204,192,181,171,161,152,144,136,128,121,114,108,0,

  // finetune -8
  907,856,808,762,720,678,640,604,570,538,508,480,
  453,428,404,381,360,339,320,302,285,269,254,240,
  226,214,202,190,180,170,160,151,143,135,127,120,0,

  // finetune -7
  900,850,802,757,715,675,636,601,567,535,505,477,
  450,425,401,379,357,337,318,300,284,268,253,238,
  225,212,200,189,179,169,159,150,142,134,126,119,0,

  // finetune -6
  894,844,796,752,709,670,632,597,563,532,502,474,
  447,422,398,376,355,335,316,298,282,266,251,237,
  223,211,199,188,177,167,158,149,141,133,125,118,0,

  // finetune -5
  887,838,791,746,704,665,628,592,559,528,498,470,
  444,419,395,373,352,332,314,296,280,264,249,235,
  222,209,198,187,176,166,157,148,140,132,125,118,0,

  // finetune -4
  881,832,785,741,699,660,623,588,555,524,494,467,
  441,416,392,370,350,330,312,294,278,262,247,233,
  220,208,196,185,175,165,156,147,139,131,123,117,0,

  // finetune -3
  875,826,779,736,694,655,619,584,551,520,491,463,
  437,413,390,368,347,328,309,292,276,260,245,232,
  219,206,195,184,174,164,155,146,138,130,123,116,0,

  // finetune -2
  868,820,774,730,689,651,614,580,547,516,487,460,
  434,410,387,365,345,325,307,290,274,258,244,230,
  217,205,193,183,172,163,154,145,137,129,122,115,0,

  // finetune -1
  862,814,768,725,684,646,610,575,543,513,484,457,
  431,407,384,363,342,323,305,288,272,256,242,228,
  216,203,192,181,171,161,152,144,136,128,121,114,0,

  // From pt2-clone:
  //
  // Arpeggio on -1 finetuned samples can do an out-of-bounds read from
  // this table. Here's the correct overflow values from the
  // "CursorPosTable" and "UnshiftedKeymap" table in the PT code, which are
  // located right after the period table. These tables and their order didn't
  // seem to change in the different PT1.x/PT2.x versions (I checked the
  // source codes).

  774,1800,2314,3087,4113,4627,5400,6426,6940,7713,
  8739,9253,24625,12851,13365
];

// dart format on
