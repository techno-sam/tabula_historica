library ring_stack;

/// A marker interface for classes that can be logically disposed - that is, when actually removed from a [RingStack].
/// If a class must also be disposed when it leaves memory, use [EphemerallyDisposable].
abstract interface class LogicallyDisposable<C> {
  /// Logically dispose of this object. Not called when, e.g. serialized to disk.
  /// This should be used to clean up long-lived resources, e.g. sidecar files.
  /// 
  /// Generally, this will be called after [EphemerallyDisposable.disposeEphemeral].
  /// 
  /// MUST be safe to call repeatedly.
  void disposeLogical(C context);
}

/// A marker interface for classes that should be disposed any time they leave memory.
abstract interface class EphemerallyDisposable<C> {
  /// Dispose of this object when it leaves memory.
  /// This should be used to clean up short-lived resources, e.g. HTTP connections.
  /// 
  /// Generally, this will be called before [LogicallyDisposable.disposeLogical].
  /// 
  /// MUST be safe to call repeatedly.
  void disposeEphemeral(C context);
}

void fullyDispose<T extends Object, C>(T obj, C context) {
  if (obj is EphemerallyDisposable<C>) {
    obj.disposeEphemeral(context);
  } else if (obj is EphemerallyDisposable) {
    throw ArgumentError.value(context, "context", "Wrong context type for EphemerallyDisposable");
  }
  if (obj is LogicallyDisposable<C>) {
    obj.disposeLogical(context);
  } else if (obj is LogicallyDisposable) {
    throw ArgumentError.value(context, "context", "Wrong context type for LogicallyDisposable");
  }
}

void ephemeralDispose<T extends Object, C>(T obj, C context) {
  if (obj is EphemerallyDisposable<C>) {
    obj.disposeEphemeral(context);
  } else if (obj is EphemerallyDisposable) {
    throw ArgumentError.value(context, "context", "Wrong context type for EphemerallyDisposable");
  }
}

class RingStack<T extends Object, C> extends Iterable<T> {
  final int capacity;
  late final List<T?> _stack = List.filled(capacity, null);
  int _size = 0;
  int _top = 0; // index of the *next* top element, grows upwards (so the top actual element is (_top - 1) % capacity)

  late final C Function() _contextSupplier;

  RingStack(this.capacity, {C Function()? contextSupplier}) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, "capacity", "Capacity must be positive");
    }
    if (contextSupplier == null) {
      if (C == Null) {
        contextSupplier = (() => null) as dynamic;
      } else {
        throw ArgumentError.notNull("contextSupplier");
      }
    }
    this._contextSupplier = contextSupplier!;
  }

  RingStack.restoreFromList(List<T> list, {int? capacity, C Function()? contextSupplier}) : capacity = capacity ?? list.length {
    if (this.capacity < list.length) {
      throw ArgumentError.value(capacity, "capacity", "Capacity must be at least the length of the list");
    }
    if (this.capacity <= 0) {
      throw ArgumentError.value(capacity, "capacity", "Capacity must be positive");
    }

    if (contextSupplier == null) {
      if (C == Null) {
        contextSupplier = (() => null) as dynamic;
      } else {
        throw ArgumentError.notNull("contextSupplier");
      }
    }
    this._contextSupplier = contextSupplier!;

    for (final T v in list.reversed) {
      push(v);
    }
  }

  @override
  Iterator<T> get iterator => _RingStackIterator(this);

  Iterator<T> get reversedIterator => _ReverseRingStackIterator(this);

  Iterable<T> get reversed => _ReverseRingStackIterable(this);

  void push(T value) {
    assert(_size <= capacity);
    // check if we're replacing a previous value
    if (_size == capacity) {
      final old = _stack[_top];
      fullyDispose(old!, _contextSupplier.call());
    } else {
      _size++;
    }
    _stack[_top] = value;
    _top = (_top + 1) % capacity;
  }

  /// Removes and returns the top element of the stack.
  /// It is the caller's responsibility to dispose of the element with [fullyDispose] if necessary.
  T pop() {
    if (_size == 0) {
      throw StateError("Cannot pop from an empty stack");
    }
    _top = (_top - 1) % capacity;
    _size--;
    final value = _stack[_top];
    _stack[_top] = null;
    return value!;
  }

  T operator [](int index) {
    if (index < 0 || index >= _size) {
      throw RangeError.index(index, this, "index", "Index out of bounds");
    }
    return _stack[(_top - 1 - index) % capacity]!;
  }

  @override
  int get length => _size;

  void clear({bool logicalDispose = false}) {
    for (var i = 0; i < _size; i++) {
      final T value = _stack[(_top - 1 - i) % capacity]!;
      if (logicalDispose) {
        fullyDispose(value, _contextSupplier.call());
      } else {
        ephemeralDispose(value, _contextSupplier.call());
      }
    }
    _size = 0;
    _top = 0;
  }

  @override
  List<T> toList({bool growable = true}) {
    final list = List<T?>.filled(_size, null, growable: growable);
    for (var i = 0; i < _size; i++) {
      list[i] = _stack[(_top - 1 - i) % capacity] as T;
    }
    return list.cast<T>();
  }

  @override
  void forEach(void Function(T element) action) {
    for (var i = 0; i < _size; i++) {
      action(_stack[(_top - 1 - i) % capacity]!);
    }
  }

  @override
  String toString() {
    return "RingStack{capacity: $capacity, size: $_size, stack: [${toList().join(", ")}]}";
  }

  @override
  bool operator ==(Object other) {
    if (other is RingStack) {
      if (other._size != _size) {
        return false;
      }
      for (var i = 0; i < _size; i++) {
        if (other[i] != this[i]) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override
  int get hashCode => Object.hashAll(this);
}

class _RingStackIterator<T extends Object, C> implements Iterator<T> {
  final RingStack<T, C> _stack;
  int _index = 0;
  T? _current;

  @pragma("wasm:prefer-inline")
  _RingStackIterator(this._stack);

  @override
  T get current => _current as T;

  @pragma("vm:prefer-inline")
  @pragma("wasm:prefer-inline")
  @override
  bool moveNext() {
    if (_index < _stack._size) {
      _current = _stack[_index];
      _index++;
      return true;
    }
    return false;
  }
}

class _ReverseRingStackIterable<T extends Object, C> extends Iterable<T> {
  final RingStack<T, C> _stack;

  _ReverseRingStackIterable(this._stack);

  @override
  Iterator<T> get iterator => _stack.reversedIterator;
}

class _ReverseRingStackIterator<T extends Object, C> implements Iterator<T> {
  final RingStack<T, C> _stack;
  int _index;
  T? _current;

  _ReverseRingStackIterator(this._stack) : _index = _stack._size - 1;

  @override
  T get current => _current as T;

  @override
  bool moveNext() {
    if (_index >= 0) {
      _current = _stack[_index];
      _index--;
      return true;
    }
    return false;
  }
}
