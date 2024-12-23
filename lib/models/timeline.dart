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
import 'package:tabula_historica/models/project/structure.dart';

class Timeline extends ChangeNotifier {
  final int minYear;
  final int maxYear;
  int _selectedYear;

  Timeline({
    required this.minYear,
    required this.maxYear,
    int selectedYear = -1,
  }) : _selectedYear = selectedYear.clamp(minYear, maxYear);

  int get selectedYear => _selectedYear;

  set selectedYear(int year) {
    year = year.clamp(minYear, maxYear);
    if (year == _selectedYear) return;
    _selectedYear = year;
    notifyListeners();
  }

  bool filter(Structure structure) {
    return (structure.builtYear == null || structure.builtYear! <= _selectedYear) &&
        (structure.destroyedYear == null || structure.destroyedYear! >= _selectedYear);
  }

  static Timeline of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }
}