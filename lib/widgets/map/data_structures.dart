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

import '../../extensions/iterables.dart';

class LODMap<V> implements Map<int, V> {
  static const _sentinel = Object();
  final int _minLOD;
  final int _maxLOD;
  final List<dynamic> _values;

  LODMap._({required int minLOD, required int maxLOD, required List<V> values}) : _minLOD = minLOD, _maxLOD = maxLOD, _values = values;

  factory LODMap.from(Map<int, V> base) {
    int minLOD = base.keys.reduce((value, element) => value < element ? value : element);
    int maxLOD = base.keys.reduce((value, element) => value > element ? value : element);

    // assert that all intermediate LODs are present
    for (int i = minLOD; i <= maxLOD; i++) {
      assert(base.containsKey(i));
    }

    return LODMap._(minLOD: minLOD, maxLOD: maxLOD, values: List<V>.generate(maxLOD - minLOD + 1, (i) => base[i + minLOD]!));
  }

  int get minLOD => _minLOD;
  int get maxLOD => _maxLOD;

  @override
  V? operator [](Object? key) {
    if (key is! int) {
      return null;
    }
    if (key < _minLOD || key > _maxLOD) {
      return null;
    }
    return _values[key - _minLOD];
  }

  @override
  void operator []=(int key, V value) {
    if (key < _minLOD || key > _maxLOD) {
      throw RangeError.range(key, _minLOD, _maxLOD, "key");
    }
    _values[key - _minLOD] = value;
  }

  @override
  void addAll(Map<int, V> other) => addEntries(other.entries);

  @override
  void addEntries(Iterable<MapEntry<int, V>> newEntries) {
    for (var entry in newEntries) {
      this[entry.key] = entry.value;
    }
  }

  @override
  Map<RK, RV> cast<RK, RV>() => Map.castFrom(this);

  @override
  void clear() {
    for (int i = 0; i < _values.length; i++) {
      _values[i] = _sentinel;
    }
  }

  @override
  bool containsKey(Object? key) {
    if (key is! int) {
      return false;
    }
    return key >= _minLOD && key <= _maxLOD && _values[key - _minLOD] != _sentinel;
  }

  @override
  bool containsValue(Object? value) {
    return _values.contains(value);
  }

  @override
  Iterable<MapEntry<int, V>> get entries => _values.asMap().entries.map((entry) => MapEntry(entry.key + _minLOD, entry.value));

  @override
  void forEach(void Function(int key, V value) action) {
    for (int i = 0; i < _values.length; i++) {
      if (_values[i] != _sentinel) {
        action(i + _minLOD, _values[i]);
      }
    }
  }

  @override
  bool get isEmpty => _values.every((element) => element == _sentinel);

  @override
  bool get isNotEmpty => _values.any((element) => element != _sentinel);

  @override
  Iterable<int> get keys => _minLOD.range(_maxLOD);

  @override
  int get length => _maxLOD - _minLOD + 1;

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(int key, V value) convert) {
    return _values.asMap().map((key, value) => convert(key + _minLOD, value));
  }

  @override
  V putIfAbsent(int key, V Function() ifAbsent) {
    if (key < _minLOD || key > _maxLOD) {
      throw RangeError.range(key, _minLOD, _maxLOD, "key");
    }
    if (_values[key - _minLOD] == _sentinel) {
      _values[key - _minLOD] = ifAbsent();
    }
    return _values[key - _minLOD];
  }

  @override
  V? remove(Object? key) {
    if (key is! int) {
      return null;
    }
    if (key < _minLOD || key > _maxLOD) {
      return null;
    }
    V value = _values[key - _minLOD];
    _values[key - _minLOD] = _sentinel;
    return value;
  }

  @override
  void removeWhere(bool Function(int key, V value) test) {
    for (int i = 0; i < _values.length; i++) {
      if (_values[i] != _sentinel && test(i + _minLOD, _values[i])) {
        _values[i] = _sentinel;
      }
    }
  }

  @override
  V update(int key, V Function(V value) update, {V Function()? ifAbsent}) {
    if (key < _minLOD || key > _maxLOD) {
      throw RangeError.range(key, _minLOD, _maxLOD, "key");
    }
    if (_values[key - _minLOD] == _sentinel) {
      if (ifAbsent == null) {
        throw StateError("Key not present and ifAbsent is null");
      }
      _values[key - _minLOD] = ifAbsent();
    }
    _values[key - _minLOD] = update(_values[key - _minLOD]);
    return _values[key - _minLOD];
  }

  @override
  void updateAll(V Function(int key, V value) update) {
    for (int i = 0; i < _values.length; i++) {
      if (_values[i] != _sentinel) {
        _values[i] = update(i + _minLOD, _values[i]);
      }
    }
  }

  @override
  Iterable<V> get values => _values.where((element) => element != _sentinel).cast();
}

extension IntoLODMap<V> on Iterable<MapEntry<int, V>> {
  LODMap<V> toLODMap() {
    return LODMap.from(Map.fromEntries(this));
  }
}

extension IntoLOD<V> on Map<int, V> {
  LODMap<V> toLODMap() {
    return LODMap.from(this);
  }
}
