import 'package:flutter_test/flutter_test.dart';

import 'package:ring_stack/ring_stack.dart';


class DisposableMock implements LogicallyDisposable<Null>, EphemerallyDisposable<Null> {
  int _logicalDisposeCount = 0;
  int _ephemeralDisposeCount = 0;
  int value;

  bool get disposedOnceLogically => _logicalDisposeCount == 1;
  bool get notDisposedLogically => _logicalDisposeCount == 0;
  bool get disposedOnceEphemerally => _ephemeralDisposeCount == 1;
  bool get notDisposedEphemerally => _ephemeralDisposeCount == 0;

  DisposableMock(this.value);

  @override
  void disposeLogical(Null _) {
    _logicalDisposeCount++;
  }

  @override
  void disposeEphemeral(Null _) {
    _ephemeralDisposeCount++;
  }

  void reset() {
    _logicalDisposeCount = 0;
    _ephemeralDisposeCount = 0;
  }
}


class ContextDisposableMock implements EphemerallyDisposable<Object> {
  int _disposeCount = 0;
  Object? _lastContext;

  bool get disposedOnce => _disposeCount == 1;
  bool get notDisposed => _disposeCount == 0;
  Object? get lastContext => _lastContext;

  @override
  void disposeEphemeral(Object context) {
    _disposeCount++;
    _lastContext = context;
  }
}


void main() {
  test('modulo works as expected', () {
    expect(5 % 3, 2);
    expect(-1 % 3, 2);
  });

  test('simple push and pop', () {
    final stack = RingStack<int, Null>(3);
    stack.push(2);
    stack.push(3);

    expect(stack.length, 2);

    stack.push(5);

    expect(stack.length, 3);
    expect(stack.pop(), 5);
    expect(stack.pop(), 3);
    expect(stack.length, 1);
    expect(stack.pop(), 2);
    expect(stack.length, 0);
  });

  test('popping empty stack throws', () {
    final stack = RingStack<int, Null>(3);
    expect(() => stack.pop(), throwsStateError);
  });

  test('popping emptied stack throws', () {
    final stack = RingStack<int, Null>(3);
    stack.push(2);
    stack.pop();
    expect(() => stack.pop(), throwsStateError);
  });

  test('pushing over capacity replaces oldest', () {
    final stack = RingStack<int, Null>(3);
    stack.push(2);
    stack.push(3);
    stack.push(5);
    stack.push(7);

    expect(stack.length, 3);
    expect(stack.pop(), 7);
    expect(stack.pop(), 5);
    expect(stack.pop(), 3);
  });

  test('post-overflow indexing works', () {
    final stack = RingStack<int, Null>(3);
    stack.push(2);
    stack.push(3);
    stack.push(5);
    stack.push(7);

    expect(stack[0], 7);
    expect(stack[1], 5);
    expect(stack[2], 3);
  });

  test('equality works', () {
    final stack1 = RingStack<int, Null>(3);
    stack1.push(2);
    stack1.push(3);
    stack1.push(5);

    final stack2 = RingStack<int, Null>(3);
    stack2.push(2);
    stack2.push(3);
    stack2.push(5);

    expect(stack1, stack2);
    expect(stack1.hashCode, stack2.hashCode);
  });

  test('inequality works', () {
    final stack1 = RingStack<int, Null>(3);
    stack1.push(2);
    stack1.push(3);
    stack1.push(5);

    final stack2 = RingStack<int, Null>(3);
    stack2.push(2);
    stack2.push(3);
    stack2.push(5);
    stack2.push(7);

    expect(stack1 != stack2, true);
    expect(stack1.hashCode != stack2.hashCode, true);
  });

  test('equality after overflow works', () {
    final stack1 = RingStack<int, Null>(3);
    stack1.push(3);
    stack1.push(5);
    stack1.push(7);

    final stack2 = RingStack<int, Null>(3);
    stack2.push(2);
    stack2.push(3);
    stack2.push(5);
    stack2.push(7);

    expect(stack1, stack2);
    expect(stack1.hashCode, stack2.hashCode);
  });

  test('clear works', () {
    final stack = RingStack<int, Null>(3);
    stack.push(2);
    stack.push(3);
    stack.push(5);

    stack.clear();

    expect(stack.length, 0);
    expect(stack.isEmpty, isTrue);
  });

  test('toList works', () {
    final stack = RingStack<int, Null>(3);
    stack.push(2);
    stack.push(3);
    stack.push(5);

    expect(stack.toList(), [5, 3, 2]);
  });

  test('restoration works', () {
    final stack = RingStack<int, Null>(3);
    stack.push(2);
    stack.push(3);
    stack.push(5);

    final restored = RingStack<int, Null>.restoreFromList(stack.toList());

    expect(stack, restored);
  });

  test('forEach works', () {
    final stack = RingStack<int, Null>(3);
    stack.push(2);
    stack.push(3);
    stack.push(5);

    final values = <int>[];
    // ignore: avoid_function_literals_in_foreach_calls
    stack.forEach((element) {
      values.add(element);
    });

    expect(values, [5, 3, 2]);
  });

  test('iteration works', () {
    final stack = RingStack<int, Null>(3);
    stack.push(2);
    stack.push(3);
    stack.push(5);

    final values = <int>[];
    for (final value in stack) {
      values.add(value);
    }

    expect(values, [5, 3, 2]);
  });

  test('dispose works', () {
    final stack = RingStack<DisposableMock, Null>(3);
    final mock1 = DisposableMock(1);
    final mock2 = DisposableMock(2);
    final mock3 = DisposableMock(3);

    stack.push(mock1);
    stack.push(mock2);
    stack.push(mock3);

    stack.clear();

    expect(mock1.disposedOnceEphemerally, isTrue);
    expect(mock2.disposedOnceEphemerally, isTrue);
    expect(mock3.disposedOnceEphemerally, isTrue);

    expect(mock1.notDisposedLogically, isTrue);
    expect(mock2.notDisposedLogically, isTrue);
    expect(mock3.notDisposedLogically, isTrue);


    mock1.reset();
    mock2.reset();
    mock3.reset();

    stack.push(mock1);
    stack.push(mock2);
    stack.push(mock3);

    stack.clear(logicalDispose: true);

    expect(mock1.disposedOnceEphemerally, isTrue);
    expect(mock2.disposedOnceEphemerally, isTrue);
    expect(mock3.disposedOnceEphemerally, isTrue);

    expect(mock1.disposedOnceLogically, isTrue);
    expect(mock2.disposedOnceLogically, isTrue);
    expect(mock3.disposedOnceLogically, isTrue);
  });

  test('dispose works with empty stack', () {
    final stack = RingStack<DisposableMock, Null>(3);
    stack.clear();
  });

  test('dispose works with non-disposable elements', () {
    final stack = RingStack<Object, Null>(3);
    final mock1 = DisposableMock(1);
    stack.push(Object());
    stack.push(mock1);
    stack.push(Object());

    stack.clear();

    expect(mock1.disposedOnceEphemerally, isTrue);
    expect(mock1.notDisposedLogically, isTrue);
  });

  test('objects are unique', () {
    expect(Object(), isNot(Object()));
  });

  test('dispose works with context', () {
    final context = Object();
    final stack = RingStack<ContextDisposableMock, Object>(2, contextSupplier: () => context);
    final mock1 = ContextDisposableMock();
    final mock2 = ContextDisposableMock();
    final mock3 = ContextDisposableMock();

    stack.push(mock1);
    stack.push(mock2);
    stack.push(mock3);

    expect(mock1.disposedOnce, isTrue);
    expect(mock1.lastContext, context);
    expect(mock2.notDisposed, isTrue);
    expect(mock3.notDisposed, isTrue);

    stack.clear();

    expect(mock1.disposedOnce, isTrue);
    expect(mock1.lastContext, context);
    expect(mock2.disposedOnce, isTrue);
    expect(mock2.lastContext, context);
    expect(mock3.disposedOnce, isTrue);
    expect(mock3.lastContext, context);
  });

  test('zero capacity throws', () {
    expect(() => RingStack<int, Null>(0), throwsArgumentError);
  });
}
