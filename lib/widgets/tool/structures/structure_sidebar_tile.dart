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
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';

import '../../../extensions/string.dart';
import '../../../logger.dart';
import '../../../models/project/history_manager.dart';
import '../../../models/project/project.dart';
import '../../../models/project/structure.dart';
import '../../../models/tools/structures_state.dart';
import '../../../models/tools/tool_selection.dart';
import '../../misc/simple_editable_text.dart';

class StructureListTile extends StatelessWidget {
  final int index;

  const StructureListTile({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolSelection = ToolSelection.of(context);
    final history = HistoryManager.of(context);
    final structure = context.watch<Structure>();

    final selected = toolSelection.selectedTool == Tool.structures &&
        toolSelection.mapStateOr((StructuresState state) =>
            state.isStructureSelected(structure), false);

    final entries = <ContextMenuEntry>[
      MenuHeader(text: structure.title),
      MenuItem(
        label: "Delete",
        onSelected: () {
          logger.d("Deleting structure ${structure.uuid}");
          Project.of(context, listen: false).removeStructure(structure);
        },
      ),
    ];

    final menu = ContextMenu(
      entries: entries,
      padding: const EdgeInsets.all(8),
    );

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? Colors.blue : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: selected ? null : () {
          toolSelection.withState((StructuresState state) {
            logger.d("Selecting structure ${structure.uuid}");
            state.selectStructure(structure);
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ContextMenuRegion(
                contextMenu: menu,
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: selected
                                ? SimpleEditableText(
                              key: ValueKey("${structure.uuid} ${structure.title}"),
                              structure.title,
                              style: theme.textTheme.titleMedium,
                              dense: true,
                              onChanged: (newTitle) =>
                                  structure.setTitle(history, newTitle),
                              addPreDisposeCallback: (callback) {
                                toolSelection.addKeyedListener(() {
                                  if (!toolSelection.mapStateOr(
                                          (StructuresState state) =>
                                          state.isStructureSelected(structure),
                                      false)) {
                                    callback();
                                  }
                                }, callback);
                              },
                              removePreDisposeCallback: (callback) {
                                toolSelection.removeKeyedListener(callback);
                              },
                            )
                                : Container(
                              alignment: Alignment.centerLeft,
                              height: 20,
                              child: Text(
                                key: ValueKey(structure.uuid),
                                structure.title,
                                style: theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              ),
              // TODO preview?
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  fixedCrossAxisSizeFactor: 1.0,
                  child: child,
                ),
                child: selected ? const _PenSelector() : const SizedBox.shrink(),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  fixedCrossAxisSizeFactor: 1.0,
                  child: child,
                ),
                child: selected ? const _TimePeriodSelector() : const SizedBox.shrink(),
              ),
            ],
          ),
        )
      ),
    );
  }
}

class _PenSelector extends StatefulWidget {
  const _PenSelector();

  @override
  State<_PenSelector> createState() => _PenSelectorState();
}

class _PenSelectorState extends State<_PenSelector> {
  final FocusNode _focusNode = FocusNode(debugLabel: "PenSelector");

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = HistoryManager.of(context);
    final structure = context.watch<Structure>();

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Text("Pen:", style: theme.textTheme.labelLarge),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<Pen>(
            value: structure.pen,
            isExpanded: true,
            focusNode: _focusNode,
            onChanged: (newPen) {
              structure.setPen(history, newPen ?? Pen.building);
              _focusNode.unfocus();
            },
            items: Pen.values.map((pen) {
              return DropdownMenuItem<Pen>(
                value: pen,
                child: Row(
                  children: [
                    Icon(
                      pen.icon,
                      color: pen.color,
                    ),
                    const SizedBox(width: 4),
                    Text(pen.toString().split('.').last.toTitleCase()),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TimePeriodSelector extends StatefulWidget {
  const _TimePeriodSelector();

  @override
  State<_TimePeriodSelector> createState() => _TimePeriodSelectorState();
}

class _TimePeriodSelectorState extends State<_TimePeriodSelector> {
  final FocusNode _focusNode = FocusNode(debugLabel: "TimePeriodSelector");

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = HistoryManager.of(context);
    final structure = context.watch<Structure>();

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Text("Period:", style: theme.textTheme.labelLarge),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<TimePeriod>(
            value: structure.timePeriod,
            isExpanded: true,
            focusNode: _focusNode,
            onChanged: (newTimePeriod) {
              structure.setTimePeriod(history, newTimePeriod ?? TimePeriod.earlyRepublic);
              _focusNode.unfocus();
            },
            items: TimePeriod.values.map((timePeriod) {
              return DropdownMenuItem<TimePeriod>(
                value: timePeriod,
                child: Text(timePeriod.toString().split('.').last.splitCamelCase().toTitleCase()),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
