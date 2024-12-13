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
import '../providers/change_notifier_field_provider.dart';
import '../../models/tools/tool_selection.dart';

class ToolSpecificEphemeral extends StatelessWidget {
  final Tool tool;
  final Widget Function(BuildContext context) builder;

  const ToolSpecificEphemeral({super.key, required this.tool, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierFieldProvider<ToolSelection, Tool>(
      field: (toolSelection) => toolSelection.selectedTool,
      child: Builder(
        builder: (context) {
          final selectedTool = context.watch<Tool>();
          if (selectedTool == tool) {
            return builder(context);
          } else {
            return const SizedBox();
          }
        },
      ),
    );
  }
}