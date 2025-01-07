import 'dart:math';
import 'dart:typed_data';

extension on int {
  bool isAlignedTo(int alignment) => this & ((1 << alignment) - 1) == 0;
}

/// Hub for chip memory contents
class Memory {
  List<Data> dataBlocks = [];
  List<Space> spaceBlocks = [];

  final int size;

  late final int dataSize;

  Memory(this.size);

  Data data({int alignment = 1, bool singlePage = false, Object? origin}) {
    Data block = Data(this, alignment: alignment, singlePage: singlePage, origin: origin);
    dataBlocks.add(block);
    return block;
  }

  Space space(int size, {int alignment = 1, bool singlePage = false, Object? origin}) {
    Space block = Space(this, size, alignment: alignment, singlePage: singlePage, origin: origin);
    spaceBlocks.add(block);
    return block;
  }

  void _allocate() {
    // TODO: Compute time ranges via dependencies to overlap space blocks.
    final List<Block> fixed = [...dataBlocks, ...spaceBlocks]
        .where((b) => b.isAllocated)
        .toList()
      ..sort((b1, b2) => b2.address! - b1.address!);

    int nextAddress = 0;

    void allocate(Block block) {
      if (!block.isAllocated) {
        block._allocateAfter(nextAddress);
        for (Block fixedBlock in fixed) {
          if (block._overlaps(fixedBlock)) {
            block._allocateAfter(fixedBlock.end);
          }
        }
        nextAddress = block.end;
      }
      if (block.end > size) {
        throw Exception("Block '$block' does not fit in memory");
      }
    }

    dataBlocks.forEach(allocate);
    spaceBlocks.forEach(allocate);

    dataSize = dataBlocks.map((b) => b.end).fold(0, max);
  }

  void _relocate() {
    for (Data block in dataBlocks) {
      block._relocate();
    }
  }

  Uint8List finalize() {
    _allocate();
    _relocate();
    Uint8List contents = Uint8List(dataSize);
    for (Data block in dataBlocks) {
      contents.setAll(block.address!, block.bytes);
    }
    return contents;
  }
}

abstract base class Label {
  int get address;
  Block get block;
  int get offsetInBlock;

  Label add(int offset) => OffsetLabel(this, offset);

  Label operator +(int offset) => add(offset);

  Label operator -(int offset) => add(-offset);

  bool isAlignedTo(int alignment) =>
      block.alignment >= alignment && offsetInBlock.isAlignedTo(alignment);
}

final class BlockLabel extends Label {
  @override
  final Block block;

  BlockLabel(this.block);

  @override
  int get address =>
      block.address ?? (throw Exception("Block '$block' not allocated"));

  @override
  int get offsetInBlock => 0;
}

final class OffsetLabel extends Label {
  final Label target;
  final int offset;

  OffsetLabel(this.target, this.offset) {
    assert(offset.isAlignedTo(1));
  }

  @override
  int get address => target.address + offset;

  @override
  Block get block => target.block;

  @override
  int get offsetInBlock => target.offsetInBlock + offset;
}

final class FreeLabel extends Label {
  String name;

  Label? _target;

  FreeLabel([this.name = "unnamed"]);

  Label get target => _target ?? (throw Exception("Label '$name' not bound"));

  void bind(Label target) {
    if (_target != null) {
      throw Exception("Label '$name' already bound");
    }
    _target = target;
  }

  bool get isBound => _target != null;

  @override
  int get address => target.address;

  @override
  Block get block => target.block;

  @override
  int get offsetInBlock => target.offsetInBlock;
}

/// A word in a data block containing part of the address of a label in the
/// same or a different block.
class Relocation {
  final int offsetInBlock;
  final Label target;
  final int shift;

  Relocation(this.offsetInBlock, this.target, this.shift);

  int get value => (target.address >> shift) & 0xFFFF;
}

/// Base class for memory blocks.
abstract base class Block {
  final Memory memory;
  final int alignment;
  final bool singlePage;
  final Object? origin;

  int? address;
  int? firstFrame;
  int? lastFrame;

  late final Label label = BlockLabel(this);

  Block(this.memory,
      {this.alignment = 1, this.singlePage = false, this.origin}) {
    assert(alignment >= 1 && alignment <= 20);
  }

  int get size;

  int get end => address! + size;

  bool get isAllocated => address != null;

  Label setLabel(int offset) => label + offset;

  @override
  String toString() => origin.toString();

  bool get _isSinglePage => (address! & 0xFFFF) + size <= 0x10000;

  void _allocateAfter(int start) {
    address = (start + (1 << alignment) - 1) & ~((1 << alignment) - 1);
    if (singlePage && !_isSinglePage) {
      if (size > 0x10000) {
        throw Exception("Block '$this' too large to fit in a single 64k page");
      }
      address = (address! & ~0xFFFF) + 0x10000;
    }
  }

  void _allocateBefore(int end) {
    address = (end - size) & ~((1 << alignment) - 1);
    if (singlePage && !_isSinglePage) {
      if (size > 0x10000) {
        throw Exception("Block '$this' too large to fit in a single 64k page");
      }
      address = ((end & ~0xFFFF) - size) & ~((1 << alignment) - 1);
    }
  }

  bool _overlaps(Block other) {
    if (address! >= other.end) return false;
    if (end <= other.address!) return false;
    return true;
  }
}

/// Memory block containing initialized data.
///
/// The block can contain relocations, which are resolved when the blocks are
/// allocated to specific addresses.
final class Data extends Block with DataContainer {
  final List<Relocation> relocations = [];

  Data(super.memory, {super.alignment, super.singlePage, super.origin});

  Label addLabel() => setLabel(size);

  void bind(FreeLabel label) {
    label.bind(addLabel());
  }

  void setRelocation(int offsetInBlock, Label target, int shift) {
    assert(offsetInBlock.isAlignedTo(1));
    relocations.add(Relocation(offsetInBlock, target, shift));
  }

  void setHigh(int offsetInBlock, Label target) {
    setRelocation(offsetInBlock, target, 16);
  }

  void setLow(int offsetInBlock, Label target) {
    setRelocation(offsetInBlock, target, 0);
  }

  void addRelocation(Label target, int shift) {
    setRelocation(size, target, shift);
    addWord(0);
  }

  void addHigh(Label target) {
    addRelocation(target, 16);
  }

  void addLow(Label target) {
    addRelocation(target, 0);
  }

  void addData(Data data) {
    Label dataLabel = addLabel();
    for (Relocation relocation in data.relocations) {
      Label target = relocation.target.block == data
          ? dataLabel + relocation.target.offsetInBlock
          : relocation.target;
      setRelocation(size + relocation.offsetInBlock, target, relocation.shift);
    }
    addBytes(data.bytes);
  }

  void _relocate() {
    for (Relocation relocation in relocations) {
      setWord(relocation.offsetInBlock, relocation.value);
    }
  }
}

/// Uninitialized memory block.
final class Space extends Block {
  @override
  final int size;

  Space(super.memory, this.size,
      {super.alignment, super.singlePage, super.origin});
}

mixin DataContainer {
  ByteData _data = ByteData(16);
  int _size = 0;

  Uint8List get bytes => Uint8List.view(_data.buffer, 0, _size);

  int get size => _size;

  void _setSize(int newSize) {
    int capacity = _data.lengthInBytes;
    if (newSize > capacity) {
      while (newSize > capacity) {
        capacity *= 2;
      }
      _data = (Uint8List(capacity)..setAll(0, _data.buffer.asUint8List()))
          .buffer
          .asByteData();
    }
    _size = newSize;
  }

  int _addSize(int addition) {
    int oldSize = _size;
    _setSize(_size + addition);
    return oldSize;
  }

  void setByte(int offset, int value) {
    assert(offset + 1 <= _size);
    _data.setUint8(offset, value);
  }

  void setWord(int offset, int value) {
    assert(offset.isAlignedTo(1));
    assert(offset + 2 <= _size);
    _data.setUint16(offset, value, Endian.big);
  }

  void setLongword(int offset, int value) {
    assert(offset.isAlignedTo(1));
    assert(offset + 4 <= _size);
    _data.setUint32(offset, value, Endian.big);
  }

  void setBytes(int offset, List<int> values) {
    assert(offset + values.length <= _size);
    for (int i = 0; i < values.length; i++) {
      _data.setUint8(offset + i, values[i]);
    }
  }

  void setWords(int offset, List<int> values) {
    assert(offset.isAlignedTo(1));
    assert(offset + values.length * 2 <= _size);
    for (int i = 0; i < values.length; i++) {
      _data.setUint16(offset + i * 2, values[i], Endian.big);
    }
  }

  void setLongwords(int offset, List<int> values) {
    assert(offset.isAlignedTo(1));
    assert(offset + values.length * 4 <= _size);
    for (int i = 0; i < values.length; i++) {
      _data.setUint32(offset + i * 4, values[i], Endian.big);
    }
  }

  void addByte(int value) => setByte(_addSize(1), value);

  void addWord(int value) => setWord(_addSize(2), value);

  void addLongword(int value) => setLongword(_addSize(4), value);

  void addBytes(List<int> values) => setBytes(_addSize(values.length), values);

  void addWords(List<int> values) =>
      setWords(_addSize(values.length * 2), values);

  void addLongwords(List<int> values) =>
      setLongwords(_addSize(values.length * 4), values);
}

extension SetAtTarget on Label {
  Data get _data {
    if (block is! Data) {
      throw Exception("Block '$block' is not a data block");
    }
    return block as Data;
  }

  void setByte(int value) => _data.setByte(offsetInBlock, value);

  void setWord(int value) => _data.setWord(offsetInBlock, value);

  void setLongword(int value) => _data.setLongword(offsetInBlock, value);

  void setBytes(List<int> values) => _data.setBytes(offsetInBlock, values);

  void setWords(List<int> values) => _data.setWords(offsetInBlock, values);

  void setLongwords(List<int> values) => _data.setLongwords(offsetInBlock, values);

  void setRelocation(Label target, int shift) =>
      _data.setRelocation(offsetInBlock, target, shift);

  void setHigh(Label target) => _data.setHigh(offsetInBlock, target);

  void setLow(Label target) => _data.setLow(offsetInBlock, target);
}
