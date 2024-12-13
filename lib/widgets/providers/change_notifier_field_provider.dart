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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChangeNotifierFieldProvider<T, F> extends StatelessWidget {

  final F Function(T) field;
  final Widget child;

  const ChangeNotifierFieldProvider({super.key, required this.field, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<T>(
      builder: (_, value, __) {
        return Provider<F>.value(
          value: field(value),
          child: child,
        );
      },
    );
  }
}