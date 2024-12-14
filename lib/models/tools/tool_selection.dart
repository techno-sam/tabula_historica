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
import 'package:tabula_historica/extensions/keyed_change_notifier.dart';
import 'package:tabula_historica/models/tools/references_state.dart';

import '../project/project.dart';

abstract class EphemeralState {
  void restoreFromJson(Project project, Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

enum Tool {
  pan("Pan", Icons.pan_tool_outlined, Icons.pan_tool),
  draw("Draw", Icons.draw_outlined, Icons.draw),
  references("References", Icons.photo_outlined, Icons.photo, ephemeralState: ReferencesState.new),
  ;

  final IconData icon;
  final IconData selectedIcon;
  final String name;
  final EphemeralState Function()? ephemeralState;

  const Tool(this.name, this.icon, this.selectedIcon, {this.ephemeralState});
}

class ToolSelection extends ChangeNotifier with KeyedChangeNotifier {
  EphemeralState? _ephemeralState;

  Tool _selectedTool = Tool.pan;

  Tool get selectedTool => _selectedTool;

  ToolSelection() {
    _createState();
  }

  ToolSelection.initial(Project project, ToolSelectionSnapshot tool) : _selectedTool = tool.selectedTool {
    _createState();
    if (tool.ephemeralState != null) {
      _ephemeralState?.restoreFromJson(project, tool.ephemeralState!);
    }
  }

  void withState<ES extends EphemeralState>(void Function(ES) callback) {
    if (_ephemeralState is ES) {
      callback(_ephemeralState as ES);
    }
  }

  T? mapState<T, ES extends EphemeralState>(T Function(ES) mapper) {
    if (_ephemeralState is ES) {
      return mapper(_ephemeralState as ES);
    }
    return null;
  }

  T mapStateOr<T, ES extends EphemeralState>(T Function(ES) mapper, T orElse) =>
      mapState(mapper) ?? orElse;

  void selectTool(Tool tool) {
    if (_selectedTool == tool) {
      return;
    }
    _selectedTool = tool;
    _createState();
    notifyListeners();
  }

  void _createState() {
    if (_ephemeralState is ChangeNotifier) {
      (_ephemeralState as ChangeNotifier).dispose();
    }
    _ephemeralState = _selectedTool.ephemeralState?.call();
    if (_ephemeralState is ChangeNotifier) {
      (_ephemeralState as ChangeNotifier).addListener(notifyListeners);
    }
  }

  @override
  void dispose() {
    if (_ephemeralState is ChangeNotifier) {
      (_ephemeralState as ChangeNotifier).dispose();
    }
    _ephemeralState = null;
    super.dispose();
  }

  ToolSelectionSnapshot get snapshot {
    return ToolSelectionSnapshot(selectedTool: selectedTool, ephemeralState: _ephemeralState?.toJson());
  }

  static ToolSelection of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }
}

class ToolSelectionSnapshot {
  final Tool selectedTool;
  final Map<String, dynamic>? ephemeralState;

  ToolSelectionSnapshot({required this.selectedTool, required this.ephemeralState});

  @override
  String toString() {
    return 'ToolSelectionSnapshot{selectedTool: $selectedTool, ephemeralState: $ephemeralState}';
  }
}