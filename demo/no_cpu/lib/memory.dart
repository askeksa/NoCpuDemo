import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'copper.dart';

extension IsAlignedTo on int {
  bool isAlignedTo(int alignment) => this & ((1 << alignment) - 1) == 0;
}

/// Hub for chip memory contents
class Memory {
  List<Data> dataBlocks = [];
  List<Space> spaceBlocks = [];

  Iterable<Block> get blocks => [...dataBlocks, ...spaceBlocks];

  final int size;

  late final int dataSize;

  Memory(this.size);

  factory Memory.fromRoots(int size, Iterable<Block> roots) {
    Set<Block> blocks = {};
    List<Block> worklist = List.from(roots);
    while (worklist.isNotEmpty) {
      Block block = worklist.removeLast();
      if (blocks.add(block)) {
        worklist.addAll(block.dependencies);
      }
    }

    Memory memory = Memory(size);
    memory.dataBlocks.addAll(blocks.whereType<Data>());
    memory.spaceBlocks.addAll(blocks.whereType<Space>());

    return memory;
  }

  void _inferLiveness() {
    void propagate(
      int? Function(Block) read,
      bool Function(Block, int) update,
      String when,
    ) {
      Set<Block> roots = blocks.where((b) => read(b) != null).toSet();
      List<Block> worklist = List.from(roots);
      while (worklist.isNotEmpty) {
        Block block = worklist.removeLast();
        for (Block dependency in block.dependencies) {
          if (!roots.contains(dependency) && update(dependency, read(block)!)) {
            worklist.add(dependency);
          }
        }
      }

      for (Block block in blocks) {
        if (read(block) == null) {
          throw Exception("No $when frame inferred for block '$block'");
        }
      }
    }

    propagate((b) => b.firstFrame, (b, f) => b._updateFirstFrame(f), "first");
    propagate((b) => b.lastFrame, (b, f) => b._updateLastFrame(f), "last");
  }

  void _deduplicate() {
    // Hack: Avoid deduplicating primary copperlists for speed.
    // TODO: Have a proper mutability flag on data blocks.
    List<List<Data>> clusters = [
      dataBlocks.where((b) {
        var origin = b.origin;
        if (origin is! Copper) return true;
        return !origin.isPrimary;
      }).toList(),
    ];

    List<List<Data>> clusterBy(bool Function(Data, Data) equals) {
      List<List<Data>> newClusters = [];
      for (List<Data> cluster in clusters) {
        List<List<Data>> newSubclusters = [];
        for (Data data in cluster) {
          bool found = false;
          for (List<Data> subcluster in newSubclusters) {
            if (equals(data, subcluster.first)) {
              subcluster.add(data);
              found = true;
              break;
            }
          }
          if (!found) {
            newSubclusters.add([data]);
          }
        }
        newClusters.addAll(newSubclusters);
      }

      for (int i = 0; i < newClusters.length; i++) {
        for (Data data in newClusters[i]) {
          data._clusterIndex = i;
        }
      }
      return newClusters;
    }

    // Cluster by shape.
    clusters = clusterBy((d1, d2) {
      if (!ListEquality().equals(d1.bytes, d2.bytes)) return false;
      if (d1.references.length != d2.references.length) return false;
      for (int i = 0; i < d1.references.length; i++) {
        Reference r1 = d1.references[i];
        Reference r2 = d2.references[i];
        if (r1.offsetInBlock != r2.offsetInBlock) return false;
        if (r1.shift != r2.shift) return false;
        if (r1.target.offsetInBlock != r2.target.offsetInBlock) return false;
      }
      return true;
    });

    // Cluster by references until no more splits occur.
    int oldSize;
    do {
      oldSize = clusters.length;
      clusters = clusterBy((d1, d2) {
        assert(d1._clusterIndex == d2._clusterIndex);
        for (int i = 0; i < d1.references.length; i++) {
          if (d1.references[i].target.block._clusterIndex !=
              d2.references[i].target.block._clusterIndex) {
            return false;
          }
        }
        return true;
      });
      assert(clusters.length >= oldSize);
    } while (clusters.length > oldSize);

    // Merge the blocks in each cluster.
    dataBlocks.removeWhere((b) {
      if (b._clusterIndex < 0) return false;
      Data representative = clusters[b._clusterIndex].first;
      if (b == representative) return false;
      representative.alignment = max(representative.alignment, b.alignment);
      representative.singlePage |= b.singlePage;
      representative.extraDependencies.addAll(b.extraDependencies);
      representative._updateFirstFrame(b.firstFrame!);
      representative._updateLastFrame(b.lastFrame!);
      // Redirect references.
      b.label.block = representative;
      return true;
    });
  }

  void _assignAddresses() {
    // TODO: Compute time ranges via dependencies to overlap space blocks.
    final List<Block> fixed =
        [...dataBlocks, ...spaceBlocks].where((b) => b.isAllocated).toList()
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

    dataSize = dataBlocks.map((b) => b.end).max;
  }

  void _resolveReferences() {
    for (Data block in dataBlocks) {
      block._resolveReferences();
    }
  }

  void finalize() {
    // Run finalizers.
    for (Data data in dataBlocks) {
      data.finalizer?.call(data);
    }
  }

  Uint8List build({bool finalize = true}) {
    if (finalize) {
      this.finalize();
    }

    // Assemble the blocks into a memory image.
    _inferLiveness();
    _deduplicate();
    _assignAddresses();
    _resolveReferences();
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
  Block block;

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
class Reference {
  final int offsetInBlock;
  final Label target;
  final int shift;

  Reference(this.offsetInBlock, this.target, this.shift);

  int get value => (target.address >> shift) & 0xFFFF;
}

/// Base class for memory blocks.
abstract base class Block {
  /// Alignment of the block.
  int alignment;

  /// Whether the block should be allocated within a single 64k page.
  bool singlePage;

  /// Object from which this block was created.
  Object? origin;

  /// Explicit dependencies on top of those implied by the references.
  final List<Block> extraDependencies = [];

  /// The memory address of the block.
  ///
  /// This can be set explicitly to assign a fixed address to the block.
  /// Otherwise, the block will be assigned an address when the memory image
  /// is built.
  int? address;

  /// The first frame where the block is used.
  ///
  /// This can be set explicitly to manually specify when the block is first
  /// used. Otherwise, the first frame will be inferred from other blocks for
  /// which this block is a dependency.
  int? firstFrame;

  /// The last frame where the block is used.
  ///
  /// This can be set explicitly to manually specify when the block is last
  /// used. Otherwise, the last frame will be inferred from other blocks for
  /// which this block is a dependency.
  int? lastFrame;

  /// Label pointing to the start of the block.
  late final BlockLabel label = BlockLabel(this);

  late int _clusterIndex = _nextClusterIndex--;
  static int _nextClusterIndex = -1;

  Block({this.alignment = 1, this.singlePage = false, this.origin}) {
    assert(alignment >= 1 && alignment <= 20);
  }

  /// Blocks that this block depends on. May contain duplicates.
  Iterable<Block> get dependencies;

  /// The size of the block.
  int get size;

  /// The end address of the block.
  int get end => address! + size;

  /// Whether the block is empty.
  bool get isEmpty => size == 0;

  /// Whether the block has been allocated to a specific address.
  bool get isAllocated => address != null;

  /// Add a block as an explicit dependency.
  void addDependency(Block block) {
    extraDependencies.add(block);
  }

  /// Mark the block as used in a given frame.
  void useInFrame(int frame) {
    _updateFirstFrame(frame);
    _updateLastFrame(frame);
  }

  bool _updateFirstFrame(int frame) {
    if (firstFrame == null || frame < firstFrame!) {
      firstFrame = frame;
      return true;
    }
    return false;
  }

  bool _updateLastFrame(int frame) {
    if (lastFrame == null || frame > lastFrame!) {
      lastFrame = frame;
      return true;
    }
    return false;
  }

  /// Set a label at a given offset from the start of the block.
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
/// The block can contain references, which are resolved after all blocks have
/// been assigned specific addresses.
final class Data extends Block with DataContainer {
  final List<Reference> references = [];

  /// Callback to run when the block is finalized.
  void Function(Data)? finalizer;

  Data({super.alignment, super.singlePage, super.origin});

  @override
  Iterable<Block> get dependencies =>
      references.map((r) => r.target.block).followedBy(extraDependencies);

  /// Add a label at the end of the block.
  Label addLabel() => setLabel(size);

  /// Bind a free label at the end of the block.
  void bind(FreeLabel label) {
    label.bind(addLabel());
  }

  /// Set a reference at a given offset from the start of the block.
  void setReference(int offsetInBlock, Label target, int shift) {
    assert(offsetInBlock.isAlignedTo(1));
    references.add(Reference(offsetInBlock, target, shift));
  }

  /// Set the high word of a reference at a given offset from the start of the
  /// block.
  void setHigh(int offsetInBlock, Label target) {
    setReference(offsetInBlock, target, 16);
  }

  /// Set the low word of a reference at a given offset from the start of the
  /// block.
  void setLow(int offsetInBlock, Label target) {
    setReference(offsetInBlock, target, 0);
  }

  /// Add a reference at the end of the block.
  void addReference(Label target, int shift) {
    setReference(size, target, shift);
    addWord(0);
  }

  /// Add the high word of a reference at the end of the block.
  void addHigh(Label target) {
    addReference(target, 16);
  }

  /// Add the low word of a reference at the end of the block.
  void addLow(Label target) {
    addReference(target, 0);
  }

  /// Add the contents of another data block to this block.
  ///
  /// The block should not have labels referenced from other blocks. Internal
  /// references and references to other blocks are fine.
  void addData(Data data) {
    Label dataLabel = addLabel();
    for (Reference reference in data.references) {
      Label target =
          reference.target.block == data
              ? dataLabel + reference.target.offsetInBlock
              : reference.target;
      setReference(size + reference.offsetInBlock, target, reference.shift);
    }
    addBytes(data.bytes);
  }

  void _resolveReferences() {
    for (Reference reference in references) {
      setWord(reference.offsetInBlock, reference.value);
    }
  }
}

/// Uninitialized memory block.
final class Space extends Block {
  @override
  final int size;

  Space(this.size, {super.alignment, super.singlePage, super.origin});

  @override
  Iterable<Block> get dependencies => extraDependencies;
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
      _data =
          (Uint8List(capacity)
            ..setAll(0, _data.buffer.asUint8List())).buffer.asByteData();
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

  void addSpace(int size) => _addSize(size);
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

  void setLongwords(List<int> values) =>
      _data.setLongwords(offsetInBlock, values);

  void setReference(Label target, int shift) =>
      _data.setReference(offsetInBlock, target, shift);

  void setHigh(Label target) => _data.setHigh(offsetInBlock, target);

  void setLow(Label target) => _data.setLow(offsetInBlock, target);
}
