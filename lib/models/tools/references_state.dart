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
import 'package:flutter/material.dart';
import 'package:tabula_historica/models/project/project.dart';

import '../project/reference.dart';
import 'tool_selection.dart';

class ReferencesState extends ChangeNotifier implements EphemeralState {
  WeakReference<Reference>? _selectedReference;

  bool isReferenceSelected(Reference reference) {
    return _selectedReference?.target == reference;
  }

  void selectReference(Reference reference) {
    if (_selectedReference?.target == reference) {
      return;
    }
    _selectedReference = WeakReference(reference);
    notifyListeners();
  }

  void deselect() {
    if (_selectedReference?.target == null) {
      return;
    }
    _selectedReference = null;
    notifyListeners();
  }

  @override
  void restoreFromJson(Project project, Map<String, dynamic> json) {
    final selectedReferenceUuid = json['selectedReference'] as String?;
    if (selectedReferenceUuid != null) {
      final reference = project.references.references
          .firstWhereOrNull((element) => element.uuid == selectedReferenceUuid);
      if (reference != null) {
        _selectedReference = WeakReference(reference);
      }
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'selectedReference': _selectedReference?.target?.uuid,
    };
  }
}
