import 'dart:io';

import 'package:collection/collection.dart';

import 'memory.dart';
import 'music.dart';

const int _instrumentsPosition = 20;
const int _instrumentSize = 30;
const int _totalInstruments = 31;

const int _patternSequenceLengthPosition = 950;
const int _patternSequencePosition = 952;
const int _patternSequenceMaxLength = 128;

const int _patternsPosition = 1084;
const int _patternSize = 1024;
const int _rowsPerPattern = 64;

const int _totalChannels = 4;

/// A row event for one channel, such as note on and/or effect
class ProtrackerEvent {
  final int? note;
  final int instrument;
  final int effect;
  final int effectParameter;

  ProtrackerEvent(
    this.note,
    this.instrument,
    this.effect,
    this.effectParameter,
  );

  ProtrackerEvent.noEffect(ProtrackerEvent event)
    : note = event.note,
      instrument = event.instrument,
      effect = 0,
      effectParameter = 0;

  factory ProtrackerEvent.readFromFile(RandomAccessFile file) {
    int rowRaw = file.readLongWordSync();

    var instrument = (rowRaw >> 24 & 0xF0) | (rowRaw >> 12 & 0x0F);
    var period = rowRaw >> 16 & 0xFFF;
    var effect = rowRaw >> 8 & 0xF;
    var effectParameter = rowRaw & 0xFF;

    int? note = period != 0 ? _periodToNote(period) : null;

    return ProtrackerEvent(note, instrument, effect, effectParameter);
  }
}

/// One channel in a pattern. A channel consists of a number of events, which
/// would be _rowsPerPattern (essentially 64).
class ProtrackerPatternEvents {
  final List<ProtrackerEvent> events = <ProtrackerEvent>[];

  void addEvent(ProtrackerEvent event) {
    events.add(event);
  }

  int get length => events.length;
}

/// A complete pattern. A pattern contains a number of
/// ProtrackerPatternEvents (most likely 4)
class ProtrackerPattern {
  final List<ProtrackerPatternEvents> channels;

  ProtrackerPattern(this.channels);

  factory ProtrackerPattern.readFromFile(
    RandomAccessFile file,
    int patternIndex,
  ) {
    var channels = List.generate(
      _totalChannels,
      (i) => ProtrackerPatternEvents(),
    );

    file.setPositionSync(_patternPosition(patternIndex));

    for (var row = 0; row < _rowsPerPattern; row++) {
      for (var channel = 0; channel < _totalChannels; channel++) {
        channels[channel].addEvent(ProtrackerEvent.readFromFile(file));
      }
    }

    return ProtrackerPattern(channels);
  }

  static int _patternPosition(int patternIndex) =>
      _patternsPosition + patternIndex * _patternSize;
}

/// An instrument subclass that adds finetune and volume.
class ProtrackerInstrument extends Instrument {
  static const _nameLength = 22;

  final int finetune;
  final int volume;
  final int lengthInFile;

  ProtrackerInstrument(
    super.data,
    super.repeat,
    super.replen,
    this.finetune,
    this.volume,
    this.lengthInFile,
  );

  factory ProtrackerInstrument.readFromFile(
    RandomAccessFile file,
    int instrumentIndex,
    int samplePosition,
  ) {
    file.setPositionSync(_instrumentPosition(instrumentIndex) + _nameLength);

    var lengthInFile = file.readWordSync() * 2;
    var finetune = file.readByteSync();
    var volume = file.readByteSync();
    var repeat = file.readWordSync() * 2;
    var replen = file.readWordSync() * 2;

    Data data = _readSampleData(
      file,
      samplePosition,
      repeat != 0 ? repeat + replen : lengthInFile,
    );

    var instrument = ProtrackerInstrument(
      data,
      repeat,
      replen,
      finetune,
      volume,
      lengthInFile,
    );
    data.origin = instrument;

    return instrument;
  }

  static int _instrumentPosition(int instrumentIndex) =>
      _instrumentsPosition + instrumentIndex * _instrumentSize;

  static Data _readSampleData(
    RandomAccessFile file,
    int samplePosition,
    int length,
  ) {
    if (length == 0) {
      return Data.fromBytes([0, 0], origin: "Empty sample");
    } else {
      file.setPositionSync(samplePosition);
      return Data.fromBytes(file.readSync(length), origin: "Sample data");
    }
  }
}

/// Represents a complete Protracker module.
class ProtrackerModule {
  final List<int> patternSequence;
  late final int _totalPatterns;
  late final List<ProtrackerPattern> patterns;
  late final List<ProtrackerInstrument> instruments;
  final int totalChannels = _totalChannels;

  ProtrackerModule(this.patternSequence, this.patterns, this.instruments);

  ProtrackerModule.readFromFile(String filename)
    : patternSequence = List.filled(
        _patternSequenceMaxLength,
        0,
        growable: true,
      ) {
    var file = File(filename).openSync();

    // Read pattern sequence first, as we need it to find the number of patterns
    _readPatternSequence(file);

    // Read all instruments and sample data
    _readInstruments(file);

    // Finally read all patterns
    patterns = List.generate(
      _totalPatterns,
      (i) => ProtrackerPattern.readFromFile(file, i),
    );
  }

  void _readPatternSequence(RandomAccessFile file) {
    file.setPositionSync(_patternSequenceLengthPosition);
    var patternSequenceLength = file.readByteSync();

    file.setPositionSync(_patternSequencePosition);
    file.readIntoSync(patternSequence);

    _totalPatterns = patternSequence.max + 1;

    patternSequence.length = patternSequenceLength;
  }

  void _readInstruments(RandomAccessFile file) {
    // The beginning of sample data
    var samplePosition = _patternsPosition + _totalPatterns * _patternSize;

    // Read all instruments
    instruments = List.generate(_totalInstruments, (i) {
      var instrument = ProtrackerInstrument.readFromFile(
        file,
        i,
        samplePosition,
      );
      samplePosition += instrument.lengthInFile;

      return instrument;
    });
  }
}

/// Handy extension methods to make reading big endian values easier.
extension Readers on RandomAccessFile {
  /// Read big-endian 16 bit integer from file
  int readWordSync() {
    var high = readByteSync();
    var low = readByteSync();

    return high << 8 | low;
  }

  /// Read big-endian 32 bit integer from file
  int readLongWordSync() {
    var b3 = readByteSync();
    var b2 = readByteSync();
    var b1 = readByteSync();
    var b0 = readByteSync();

    return b3 << 24 | b2 << 16 | b1 << 8 | b0;
  }
}

int _periodToNote(int period) {
  return _notePeriods.indexOf(period);
}

// dart format off
const List<int> _notePeriods = [
  856,808,762,720,678,640,604,570,538,508,480,453,
  428,404,381,360,339,320,302,285,269,254,240,226,
  214,202,190,180,170,160,151,143,135,127,120,113
];
// dart format on
