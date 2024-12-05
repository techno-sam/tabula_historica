/*
 * Doodle Tracks
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

enum Tool {
  pan("Pan", Icons.pan_tool_outlined, Icons.pan_tool),
  draw("Draw", Icons.draw_outlined, Icons.draw),
  ;

  final IconData icon;
  final IconData selectedIcon;
  final String name;

  const Tool(this.name, this.icon, [IconData? selectedIcon]) : selectedIcon = selectedIcon ?? icon;
}

class ToolSelection extends ChangeNotifier {
  Tool _selectedTool = Tool.pan;

  Tool get selectedTool => _selectedTool;

  void selectTool(Tool tool) {
    _selectedTool = tool;
    notifyListeners();
  }

  static ToolSelection of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }
}