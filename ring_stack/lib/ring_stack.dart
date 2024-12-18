library ring_stack;

/// A marker interface for classes that can be logically disposed - that is, when actually removed from a [RingStack].
/// If a class must also be disposed when it leaves memory, use [EphemerallyDisposable].
abstract interface class LogicallyDisposable {
  /// Logically dispose of this object. Not called when, e.g. serialized to disk.
  /// This should be used to clean up long-lived resources, e.g. sidecar files.
  /// 
  /// Generally, this will be called after [EphemerallyDisposable.disposeEphemeral].
  /// 
  /// MUST be safe to call repeatedly.
  void disposeLogical();
}

/// A marker interface for classes that should be disposed any time they leave memory.
abstract interface class EphemerallyDisposable {
  /// Dispose of this object when it leaves memory.
  /// This should be used to clean up short-lived resources, e.g. HTTP connections.
  /// 
  /// Generally, this will be called before [LogicallyDisposable.disposeLogical].
  /// 
  /// MUST be safe to call repeatedly.
  void disposeEphemeral();
}

void fullyDispose(Object obj) {
  if (obj is EphemerallyDisposable) {
    obj.disposeEphemeral();
  }
  if (obj is LogicallyDisposable) {
    obj.disposeLogical();
  }
}

void ephemeralDispose(Object obj) {
  if (obj is EphemerallyDisposable) {
    obj.disposeEphemeral();
  }
}

class RingStack<T extends Object> extends Iterable<T> {
  final int capacity;
  late final List<T?> _stack = List.filled(capacity, null);
  int _size = 0;
  int _top = 0; // index of the *next* top element, grows upwards (so the top actual element is (_top - 1) % capacity)

  RingStack(this.capacity) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, "capacity", "Capacity must be positive");
    }
  }

  RingStack.restoreFromList(List<T> list, {int? capacity}) : capacity = capacity ?? list.length {
    if (this.capacity < list.length) {
      throw ArgumentError.value(capacity, "capacity", "Capacity must be at least the length of the list");
    }
    if (this.capacity <= 0) {
      throw ArgumentError.value(capacity, "capacity", "Capacity must be positive");
    }
    for (final T v in list.reversed) {
      push(v);
    }
  }

  @override
  Iterator<T> get iterator => _RingStackIterator(this);

  void push(T value) {
    assert(_size <= capacity);
    // check if we're replacing a previous value
    if (_size == capacity) {
      final old = _stack[_top];
      fullyDispose(old!);
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
      final value = _stack[(_top - 1 - i) % capacity];
      if (value is EphemerallyDisposable) {
        value.disposeEphemeral();
      }
      if (logicalDispose && value is LogicallyDisposable) {
        value.disposeLogical();
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
  void forEach(void Function(T element) f) {
    for (var i = 0; i < _size; i++) {
      f(_stack[(_top - 1 - i) % capacity]!);
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

class _RingStackIterator<T extends Object> implements Iterator<T> {
  final RingStack<T> _stack;
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
