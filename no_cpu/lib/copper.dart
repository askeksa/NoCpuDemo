import 'custom.dart';
import 'memory.dart';

typedef RegisterCallback = void Function(int register, Label label);

/// A sequence of copper instructions.
class Copper {
  /// Data for the copperlist.
  final Data data;

  /// Is this a copperlist pointed to by COP1LC?
  final bool isPrimary;

  /// Object from which this copperlist was created.
  Object? origin;

  /// Callback to run when the copper is finalized.
  void Function(Copper)? finalizer;

  /// Is this copperlist terminated?
  bool isTerminated = false;

  final List<(Set<int>, RegisterCallback)> _watchStack = [];

  Copper({
    int alignment = 2,
    this.isPrimary = false,
    Mutability? mutability,
    this.origin,
  }) : data = Data(
         alignment: alignment,
         singlePage: isPrimary,
         mutability: mutability ?? Mutability.immutable,
       ) {
    data.origin = this;
    data.finalizer = (_) {
      finalizer?.call(this);
      if (!isTerminated) {
        if (isPrimary) {
          end();
        } else {
          ret();
        }
      }
    };
  }

  /// Label at the start of the copperlist.
  Label get label => data.label;

  /// Whether the copperlist is empty.
  bool get isEmpty => data.isEmpty;

  Mutability get mutability => data.mutability;
  set mutability(Mutability value) => data.mutability = value;
  bool get isMutable => data.isMutable;

  /// Mark the copperlist as used in a given frame.
  void useInFrame(int frame) => data.useInFrame(frame);

  @override
  String toString() => "Copper: $origin";

  void _pushWatch(Iterable<int> registers, RegisterCallback callback) {
    _watchStack.add((registers.toSet(), callback));
  }

  void _popWatch() {
    _watchStack.removeLast();
  }

  void _move(int register, void Function() value, {FreeLabel? label}) {
    assert(!isTerminated);
    data.addWord(register);
    value();
    late Label valueLabel = data.addLabel() - 2;
    label?.bind(valueLabel);
    for (var (registers, callback) in _watchStack) {
      if (registers.contains(register)) {
        callback(register, valueLabel);
      }
    }
  }

  /// A copper MOVE instruction.
  ///
  /// The optional [label] is bound to the value word.
  void move(int register, int value, {FreeLabel? label}) {
    _move(register, () => data.addWord(value), label: label);
  }

  /// A copper MOVE instruction with the high word of a reference as value.
  ///
  /// The optional [label] is bound to the value word.
  void high(int register, Label target, {FreeLabel? label}) {
    _move(register, () => data.addHigh(target), label: label);
  }

  /// A copper MOVE instruction with the low word of a reference as value.
  ///
  /// The optional [label] is bound to the value word.
  void low(int register, Label target, {FreeLabel? label}) {
    _move(register, () => data.addLow(target), label: label);
  }

  /// Two copper MOVE instructions setting a full pointer value.
  void ptr(int register, Label target) {
    high(register, target);
    low(register + 2, target);
  }

  void _waitOrSkip(
    int v,
    int h,
    int vmask,
    int hmask,
    bool blitter,
    int skipFlag,
  ) {
    assert(!isTerminated);
    assert(vmask & ~0x7F == 0x80);
    assert(hmask & ~0xFE == 0x00);
    data.addWord(((v & 0xFF) << 8) | (h & 0xFE) | 0x0001);
    data.addWord(
      (blitter ? 0x0000 : 0x8000) |
          ((vmask & 0x7F) << 8) |
          (hmask & 0xFE) |
          skipFlag,
    );
  }

  /// A copper WAIT instruction.
  void wait({
    required int v,
    int h = 0x01,
    int vmask = 0xFF,
    int hmask = 0xFE,
    bool blitter = false,
  }) {
    _waitOrSkip(v, h, vmask, hmask, blitter, 0x0000);
  }

  /// A copper WAIT instruction that just waits for the blitter.
  void waitBlit() => wait(v: 0, vmask: 0x80, hmask: 0x00, blitter: true);

  /// A copper SKIP instruction.
  void skip({
    required int v,
    int h = 0x01,
    int vmask = 0xFF,
    int hmask = 0xFE,
    bool blitter = false,
  }) {
    _waitOrSkip(v, h, vmask, hmask, blitter, 0x0001);
  }

  /// A copper SKIP instruction that just skips if the blitter is idle.
  void skipBlit() => skip(v: 0, vmask: 0x80, hmask: 0x00, blitter: true);

  /// Terminate the copperlist.
  void end() {
    data.addLongword(0xFFFFFFFE);
    isTerminated = true;
  }
}

extension CopperCall on Copper {
  /// Call a secondary copperlist.
  void call(Copper target) {
    assert(!target.isPrimary);
    if (isPrimary) {
      // Returning call
      var returnLabel = FreeLabel("return");
      low(COP1LCL, returnLabel);
      ptr(COP2LC, target.label);
      move(COPJMP2, 0);
      data.bind(returnLabel);
    } else {
      // Tail call
      ptr(COP2LC, target.label);
      move(COPJMP2, 0);
      isTerminated = true;
    }
  }

  /// Return from a called copperlist.
  void ret() {
    assert(!isPrimary);
    move(COPJMP1, 0);
    isTerminated = true;
  }
}

/// Something that can generate copper instructions.
abstract interface class CopperComponent {
  void addToCopper(Copper copper);
}

class AdHocCopperComponent implements CopperComponent {
  final void Function(Copper) callback;

  AdHocCopperComponent(this.callback);

  @override
  void addToCopper(Copper copper) => callback(copper);
}

extension ComponentsInCopper on Copper {
  Copper addComponent(CopperComponent component) {
    component.addToCopper(this);
    return this;
  }

  Copper callComponent(CopperComponent component) {
    var copper = Copper(origin: component);
    component.addToCopper(copper);
    if (!copper.isEmpty) {
      call(copper);
    }
    return this;
  }

  Copper added(void Function(Copper) callback) =>
      addComponent(AdHocCopperComponent(callback));

  Copper called(void Function(Copper) callback) =>
      callComponent(AdHocCopperComponent(callback));

  Copper operator <<(CopperComponent component) => addComponent(component);

  Copper operator >>(CopperComponent component) => callComponent(component);

  Copper operator |(void Function(Copper) callback) => added(callback);

  Copper operator ^(void Function(Copper) callback) => called(callback);
}

extension CopperComponentOperators on CopperComponent {
  CopperComponent operator +(CopperComponent other) =>
      AdHocCopperComponent((copper) {
        addToCopper(copper);
        other.addToCopper(copper);
      });

  CopperComponent operator <<(CopperComponent other) =>
      AdHocCopperComponent((copper) {
        addToCopper(copper);
        copper << other;
      });

  CopperComponent operator >>(CopperComponent other) =>
      AdHocCopperComponent((copper) {
        addToCopper(copper);
        copper >> other;
      });

  CopperComponent operator |(void Function(Copper) callback) =>
      AdHocCopperComponent((copper) {
        addToCopper(copper);
        copper | callback;
      });

  CopperComponent operator ^(void Function(Copper) callback) =>
      AdHocCopperComponent((copper) {
        addToCopper(copper);
        copper ^ callback;
      });

  CopperComponent watch(Iterable<int> registers, RegisterCallback callback) =>
      AdHocCopperComponent((copper) {
        copper._pushWatch(registers, callback);
        addToCopper(copper);
        copper._popWatch();
      });

  CopperComponent bind(Map<int, FreeLabel> labels) =>
      watch(labels.keys, (register, label) => labels[register]?.bind(label)) |
      (_) {
        for (var register in labels.keys) {
          var label = labels[register]!;
          if (!label.isBound) {
            String reg = register.toRadixString(16).padLeft(3, '0');
            throw Exception(
              "Label ${label.name} was not bound to register \$$reg",
            );
          }
        }
      };

  CopperComponent operator /(Map<int, FreeLabel> labels) => bind(labels);
}

extension JoinCopperComponents on Iterable<CopperComponent> {
  CopperComponent get joined {
    return AdHocCopperComponent((copper) {
      for (var component in this) {
        component.addToCopper(copper);
      }
    });
  }
}
