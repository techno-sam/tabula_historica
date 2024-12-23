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
import 'project/structure.dart';

class StructureInfoSelection extends ChangeNotifier {
  Structure? _selectedStructure;

  StructureInfoSelection({Structure? selectedStructure}) : _selectedStructure = selectedStructure;

  Structure? get selectedStructure => _selectedStructure;

  set selectedStructure(Structure? structure) {
    if (structure == _selectedStructure) return;
    _selectedStructure = structure;
    notifyListeners();
  }

  static StructureInfoSelection of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }
}