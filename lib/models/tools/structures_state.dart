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

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../project/project.dart';
import '../project/structure.dart';
import 'tool_selection.dart';

class StructuresState extends ChangeNotifier implements EphemeralState {
  WeakReference<Structure>? _selectedStructure;

  bool isStructureSelected(Structure structure) {
    return _selectedStructure?.target == structure;
  }

  void selectStructure(Structure structure) {
    if (_selectedStructure?.target == structure) {
      return;
    }
    _selectedStructure = WeakReference(structure);
    notifyListeners();
  }

  void deselect() {
    if (_selectedStructure?.target == null) {
      return;
    }
    _selectedStructure = null;
    notifyListeners();
  }

  @override
  void restoreFromJson(Project project, Map<String, dynamic> json) {
    final selectedStructureUuid = json['selectedStructure'] as String?;
    if (selectedStructureUuid != null) {
      final structure = project.structures.structures
          .firstWhereOrNull((element) => element.uuid == selectedStructureUuid);
      if (structure != null) {
        _selectedStructure = WeakReference(structure);
      }
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'selectedStructure': _selectedStructure?.target?.uuid,
    };
  }
}
