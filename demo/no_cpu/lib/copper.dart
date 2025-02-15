import 'custom.dart';
import 'memory.dart';

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

  Copper({int alignment = 2, this.isPrimary = false, this.origin})
      : data = Data(alignment: alignment, singlePage: isPrimary) {
    data.origin = this;
    data.finalizer = (_) {
      if (finalizer != null) {
        finalizer!(this);
      } else {
        if (!isTerminated) {
          if (isPrimary) {
            end();
          } else {
            ret();
          }
        }
      }
    };
  }

  /// Label at the start of the copperlist.
  Label get label => data.label;

  /// Whether the copperlist is empty.
  bool get isEmpty => data.isEmpty;

  /// Mark the copperlist as used in a given frame.
  void useInFrame(int frame) => data.useInFrame(frame);

  @override
  String toString() => "Copper: $origin";

  void _move(int register, void Function() value, {FreeLabel? label}) {
    assert(!isTerminated);
    data.addWord(register);
    label?.bind(data.addLabel());
    value();
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
      int v, int h, int vmask, int hmask, bool blitter, int skipFlag) {
    assert(!isTerminated);
    assert(vmask & ~0x7F == 0x80);
    assert(hmask & ~0xFE == 0x00);
    data.addWord(((v & 0xFF) << 8) | (h & 0xFE) | 0x0001);
    data.addWord((blitter ? 0x0000 : 0x8000) |
        ((vmask & 0x7F) << 8) |
        (hmask & 0xFE) |
        skipFlag);
  }

  /// A copper WAIT instruction.
  void wait(
      {required int v,
      int h = 0x01,
      int vmask = 0xFF,
      int hmask = 0xFE,
      bool blitter = false}) {
    _waitOrSkip(v, h, vmask, hmask, blitter, 0x0000);
  }

  /// A copper WAIT instruction that just waits for the blitter.
  void waitBlit() => wait(v: 0, vmask: 0x80, hmask: 0x00, blitter: true);

  /// A copper SKIP instruction.
  void skip(
      {required int v,
      int h = 0x01,
      int vmask = 0xFF,
      int hmask = 0xFE,
      bool blitter = false}) {
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
    assert(isPrimary && !target.isPrimary);
    var returnLabel = FreeLabel("return");
    low(COP1LCL, returnLabel);
    ptr(COP2LC, target.label);
    move(COPJMP2, 0);
    data.bind(returnLabel);
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

extension ComponentsInCopper on Copper {
  void addComponent(CopperComponent component) {
    component.addToCopper(this);
  }

  void addComponentCalled(CopperComponent component) {
    var copper = Copper(origin: component);
    component.addToCopper(copper);
    if (copper.isEmpty) return;

    call(copper);
  }

  void operator <<(CopperComponent component) => addComponent(component);

  void operator >>(CopperComponent component) => addComponentCalled(component);
}

class JoinedCopperComponents implements CopperComponent {
  final List<CopperComponent> components;

  JoinedCopperComponents(this.components);

  @override
  void addToCopper(Copper copper) {
    for (var component in components) {
      component.addToCopper(copper);
    }
  }
}

extension JoinCopperComponents on CopperComponent {
  CopperComponent operator +(CopperComponent other) =>
      JoinedCopperComponents([this, other]);
}
