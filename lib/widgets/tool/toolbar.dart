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

import '../../extensions/iterables.dart';
import '../../models/tools/tool_selection.dart';

class _FunctionalWidgetStateProperty<T> extends WidgetStateProperty<T> {
  final T Function(Set<WidgetState> states) _resolve;

  _FunctionalWidgetStateProperty(this._resolve);

  @override
  T resolve(Set<WidgetState> states) => _resolve(states);
}

class Toolbar extends StatelessWidget {
  const Toolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolSelection = ToolSelection.of(context);

    return Card.outlined(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Row(
          children: Tool.values
              .map<Widget>((tool) => _ToolButton(tool: tool, toolSelection: toolSelection))
              .withSeparator(const SizedBox(
                height: 50,
                width: 16,
                child: VerticalDivider(
                  color: Colors.black,
                  thickness: 0.75,
                ),
              )).toList(growable: false),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.tool,
    required this.toolSelection,
  });

  final Tool tool;
  final ToolSelection toolSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = toolSelection.selectedTool == tool;

    return Column(
      children: [
        IconButton(
          icon: Icon(tool.icon),
          selectedIcon: Icon(tool.selectedIcon),
          isSelected: selected,
          onPressed: () => toolSelection.selectTool(tool),
          color: selected ? Colors.blue : Colors.black,
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            foregroundColor: _FunctionalWidgetStateProperty((states) {
              if (states.contains(WidgetState.disabled)) {
                return theme.colorScheme.onSurface.withOpacity(0.38);
              }
              if (states.contains(WidgetState.selected)) {
                return Colors.blue;
              }
              return theme.colorScheme.onSurfaceVariant;
            }),
            backgroundColor: _FunctionalWidgetStateProperty((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.blue.withOpacity(0.1);
              }
              return theme.colorScheme.onSurfaceVariant.withOpacity(0.04);
            }),
          ),
        ),
        Text(tool.name, style: theme.textTheme.labelSmall)
      ],
    );
  }
}
