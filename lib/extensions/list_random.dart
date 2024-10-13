import 'dart:math';

extension RandomList<T> on List<T> {
  T choose(Random random) {
    return this[random.nextInt(length)];
  }
}