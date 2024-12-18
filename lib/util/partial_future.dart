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

class PartialFuture<I, F> {
  final I value;
  final Future<F> future;

  PartialFuture({required this.value, required this.future});

  PartialFuture.value(this.value) : future = Future.value(null);

  PartialFuture<I1, F1> map<I1, F1>(I1 Function(I) valueMapper, Future<F1> Function(F) futureMapper) =>
      PartialFuture<I1, F1>(value: valueMapper(value), future: future.then(futureMapper));

  PartialFuture<I1, F> mapValue<I1>(I1 Function(I) mapper) =>
      PartialFuture<I1, F>(value: mapper(value), future: future);

  PartialFuture<I, F1> mapFuture<F1>(Future<F1> Function(F) mapper) =>
      PartialFuture<I, F1>(value: value, future: future.then(mapper));

  static PartialFuture<Immediate, Fut> fromComputation<Immediate, Fut>(Future<Fut> Function() future, Immediate value) {
    return PartialFuture(value: value, future: future());
  }
}