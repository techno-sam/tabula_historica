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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    structure.pen.icon,
                                    color: structure.pen.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      key: ValueKey(structure.uuid),
                                      structure.title,
                                      style: theme.textTheme.titleMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Divider(
                              color: structure.timePeriod.color,
                              thickness: 2,
                            ),
                          ),
                          Flexible(
                            child: Divider(
                              color: structure.lastTimePeriod.color,
                              thickness: 2,
                            ),
                          )
                        ],
                      ),
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  fixedCrossAxisSizeFactor: 1.0,
                  child: child,
                ),
                child: selected ? const _LastTimePeriodSelector() : const SizedBox.shrink(),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  fixedCrossAxisSizeFactor: 1.0,
                  child: child,
                ),
                child: selected ? const _InfoCardDetailsConfigurator() : const SizedBox.shrink(),
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
          child: TapRegion(
            onTapOutside: (_) => _focusNode.unfocus(),
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
          child: TapRegion(
            onTapOutside: (_) => _focusNode.unfocus(),
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
        ),
      ],
    );
  }
}

class _LastTimePeriodSelector extends StatefulWidget {
  const _LastTimePeriodSelector();

  @override
  State<_LastTimePeriodSelector> createState() => _LastTimePeriodSelectorState();
}

class _LastTimePeriodSelectorState extends State<_LastTimePeriodSelector> {
  final FocusNode _focusNode = FocusNode(debugLabel: "LastTimePeriodSelector");

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
        Text("Last Period:", style: theme.textTheme.labelLarge),
        const SizedBox(width: 8),
        Expanded(
          child: TapRegion(
            onTapOutside: (_) => _focusNode.unfocus(),
            child: DropdownButton<TimePeriod>(
              key: ValueKey("LastTimePeriodSelector ${structure.uuid} ${structure.lastTimePeriod}"),
              value: structure.lastTimePeriod,
              isExpanded: true,
              focusNode: _focusNode,
              onChanged: (newLastTimePeriod) {
                structure.setLastTimePeriod(history, newLastTimePeriod ?? TimePeriod.earlyRepublic);
                _focusNode.unfocus();
              },
              items: TimePeriod.values.map((lastTimePeriod) {
                return DropdownMenuItem<TimePeriod>(
                  value: lastTimePeriod,
                  child: Text(lastTimePeriod.toString().split('.').last.splitCamelCase().toTitleCase()),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// configure builtYear, builtBy, destroyedYear, destroyedBy, and imageURL

class _InfoCardDetailsConfigurator extends StatefulWidget {
  const _InfoCardDetailsConfigurator();

  @override
  State<_InfoCardDetailsConfigurator> createState() => _InfoCardDetailsConfiguratorState();
}

class _InfoCardDetailsConfiguratorState extends State<_InfoCardDetailsConfigurator> {
  final FocusNode _focusNode1 = FocusNode(debugLabel: "InfoCardDetailsConfigurator 1");
  final FocusNode _focusNode2 = FocusNode(debugLabel: "InfoCardDetailsConfigurator 2");
  final FocusNode _focusNode3 = FocusNode(debugLabel: "InfoCardDetailsConfigurator 3");
  final FocusNode _focusNode4 = FocusNode(debugLabel: "InfoCardDetailsConfigurator 4");
  final FocusNode _focusNode5 = FocusNode(debugLabel: "InfoCardDetailsConfigurator 5");

  String? _textFieldValue1;
  String? _textFieldValue2;
  String? _textFieldValue3;
  String? _textFieldValue4;
  String? _textFieldValue5;

  @override
  void dispose() {
    _focusNode1.dispose();
    _focusNode2.dispose();
    _focusNode3.dispose();
    _focusNode4.dispose();
    _focusNode5.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = HistoryManager.of(context);
    final structure = context.watch<Structure>();

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text("Built Year:", style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            Expanded(
              child: TapRegion(
                onTapOutside: (_) {
                  _focusNode1.unfocus();
                  if (_textFieldValue1 != null) {
                    structure.setBuiltYear(history, int.tryParse(_textFieldValue1!) ?? 0);
                  }
                },
                child: TextField(
                  focusNode: _focusNode1,
                  controller: TextEditingController(
                      text: structure.builtYear?.toString() ?? ""),
                  keyboardType: TextInputType.number,
                  onChanged: (newBuiltYear) {
                    _textFieldValue1 = newBuiltYear;
                  },
                  onSubmitted: (newBuiltYear) {
                    structure.setBuiltYear(
                        history, int.tryParse(newBuiltYear) ?? 0);
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text("Built By:", style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            Expanded(
              child: TapRegion(
                onTapOutside: (_) {
                  _focusNode2.unfocus();
                  if (_textFieldValue2 != null) {
                    structure.setBuiltBy(history, _textFieldValue2!.emptyToNull());
                  }
                },
                child: TextField(
                  focusNode: _focusNode2,
                  controller: TextEditingController(text: structure.builtBy ?? ""),
                  onChanged: (newBuiltBy) {
                    _textFieldValue2 = newBuiltBy;
                  },
                  onSubmitted: (newBuiltBy) {
                    structure.setBuiltBy(history, newBuiltBy.emptyToNull());
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text("Destroyed Year:", style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            Expanded(
              child: TapRegion(
                onTapOutside: (_) {
                  _focusNode3.unfocus();
                  if (_textFieldValue3 != null) {
                    structure.setDestroyedYear(history, int.tryParse(_textFieldValue3!) ?? 0);
                  }
                },
                child: TextField(
                  focusNode: _focusNode3,
                  controller: TextEditingController(
                      text: structure.destroyedYear?.toString() ?? ""),
                  keyboardType: TextInputType.number,
                  onChanged: (newDestroyedYear) {
                    _textFieldValue3 = newDestroyedYear;
                  },
                  onSubmitted: (newDestroyedYear) {
                    structure.setDestroyedYear(
                        history, int.tryParse(newDestroyedYear) ?? 0);
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text("Destroyed By:", style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            Expanded(
              child: TapRegion(
                onTapOutside: (_) {
                  _focusNode4.unfocus();
                  if (_textFieldValue4 != null) {
                    structure.setDestroyedBy(history, _textFieldValue4!.emptyToNull());
                  }
                },
                child: TextField(
                  focusNode: _focusNode4,
                  controller: TextEditingController(
                      text: structure.destroyedBy ?? ""),
                  onChanged: (newDestroyedBy) {
                    _textFieldValue4 = newDestroyedBy;
                  },
                  onSubmitted: (newDestroyedBy) {
                    structure.setDestroyedBy(history, newDestroyedBy.emptyToNull());
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text("Image URL:", style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            Expanded(
              child: TapRegion(
                onTapOutside: (_) {
                  _focusNode5.unfocus();
                  if (_textFieldValue5 != null) {
                    structure.setImageURL(history, _textFieldValue5!.isEmpty ? null : Uri.tryParse(_textFieldValue5!));
                  }
                },
                child: TextField(
                  focusNode: _focusNode5,
                  controller: TextEditingController(text: structure.imageURL?.toString() ?? ""),
                  onChanged: (newImageURL) {
                    _textFieldValue5 = newImageURL;
                  },
                  onSubmitted: (newImageURL) {
                    structure.setImageURL(history, newImageURL.isEmpty ? null : Uri.tryParse(newImageURL));
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
