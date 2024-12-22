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
import 'package:tabula_historica/extensions/iterables.dart';

import '../project/project.dart';
import '../project/structure.dart';
import 'tool_selection.dart';

class StructuresState extends ChangeNotifier implements EphemeralState {
  WeakReference<Structure>? _selectedStructure;
  Width _penWidth = Width.normal;
  TimePeriod _timePeriod = TimePeriod.earlyRepublic;
  Set<TimePeriod> _visibility = TimePeriod.values.toSet();

  Width get penWidth => _penWidth;
  set penWidth(Width penWidth) {
    if (penWidth != _penWidth) {
      _penWidth = penWidth;
      notifyListeners();
    }
  }

  TimePeriod get timePeriod => _timePeriod;
  set timePeriod(TimePeriod timePeriod) {
    if (timePeriod != _timePeriod) {
      _timePeriod = timePeriod;
      notifyListeners();
    }
  }

  Iterable<TimePeriod> get visibility => _visibility;

  bool visibilityFilter(Structure structure) {
    for (final timePeriod in _visibility) {
      if (structure.visibleForFilter(timePeriod)) {
        return true;
      }
    }
    return false;
  }
  bool isVisible(TimePeriod timePeriod) => _visibility.contains(timePeriod);
  void setVisibility(TimePeriod timePeriod, bool visible) {
    if (visible) {
      _visibility.add(timePeriod);
    } else {
      _visibility.remove(timePeriod);
    }
    notifyListeners();
  }

  Structure? get selectedStructure => _selectedStructure?.target;
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
    penWidth = Width.fromJson(json['penWidth']);
    timePeriod = TimePeriod.fromJson(json['timePeriod']);
    _visibility = json.mapSingle(
        'visibility',
            (l) => (l as List<String>).map(
                    (e) => TimePeriod.fromJson(e)
            ).toSet()
    ) ?? _visibility;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'selectedStructure': _selectedStructure?.target?.uuid,
      'penWidth': _penWidth.toJson(),
      'timePeriod': _timePeriod.toJson(),
      'visibility': _visibility.map((e) => e.toJson()).toList(),
    };
  }
}
