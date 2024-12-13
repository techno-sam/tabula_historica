/*
 * Tabula Historica
 * Copyright (C) 2024  Sam Wagenaar
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

extension RangeableInt on int {
  Iterable<int> range(int end) sync* {
    for (var i = this; i < end; i++) {
      yield i;
    }
  }
}

extension Separatable<T> on Iterable<T> {
  Iterable<T> withSeparator(T separator) sync* {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return;
    }
    yield iterator.current;
    while (iterator.moveNext()) {
      yield separator;
      yield iterator.current;
    }
  }

  Iterable<T> withFactorySeparator(T Function() separator) sync* {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return;
    }
    yield iterator.current;
    while (iterator.moveNext()) {
      yield separator();
      yield iterator.current;
    }
  }
}

extension TupleToMap<K, V> on Iterable<(K, V)> {
  Map<K, V> tupleToMap() {
    return Map.fromEntries(map((e) => MapEntry(e.$1, e.$2)));
  }
}

extension MapSingleValue<K, V> on Map<K, V> {
  T? mapSingle<T>(K key, T Function(V) mapper) {
    final value = this[key];
    if (value == null) {
      return null;
    }
    return mapper(value);
  }
}