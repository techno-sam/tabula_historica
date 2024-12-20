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
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:provider/provider.dart';

import '../../misc/simple_editable_text.dart';
import '../../../logger.dart';
import '../../../models/project/project.dart';
import '../../../models/project/history_manager.dart';
import '../../../models/project/reference.dart';
import '../../../models/tools/references_state.dart';
import '../../../models/tools/tool_selection.dart';

class ReferenceListTile extends StatelessWidget {
  final int index;

  const ReferenceListTile({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    timeDilation = 1.0;
    final theme = Theme.of(context);
    final toolSelection = ToolSelection.of(context);
    final history = HistoryManager.of(context);
    final reference = context.watch<Reference>();

    final selected = toolSelection.selectedTool == Tool.references &&
        toolSelection.mapStateOr((ReferencesState state) =>
            state.isReferenceSelected(reference), false);

    final entries = <ContextMenuEntry>[
      MenuHeader(text: reference.title),
      MenuItem(
        label: "Delete",
        onSelected: () async {
          logger.d("Deleting reference ${reference.uuid}");
          await Project.of(context, listen: false).removeReference(reference);
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
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: selected ? Colors.blue : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: selected ? null : () {
          toolSelection.withState((ReferencesState state) {
            logger.d("Selecting reference ${reference.uuid}");
            state.selectReference(reference);
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
                                    key: ValueKey("${reference.uuid} ${reference.title}"),
                                    reference.title,
                                    style: theme.textTheme.titleMedium,
                                    dense: true,
                                    onChanged: (newTitle) =>
                                        reference.setTitle(history, newTitle),
                                    addPreDisposeCallback: (callback) {
                                      toolSelection.addKeyedListener(() {
                                        if (!toolSelection.mapStateOr(
                                            (ReferencesState state) =>
                                                state.isReferenceSelected(reference),
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
                                      key: ValueKey(reference.uuid),
                                      reference.title,
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.file(
                    reference.image.toFile(),
                    width: 180,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => SizeTransition(
                      sizeFactor: animation,
                      fixedCrossAxisSizeFactor: 1.0,
                      child: child,
                    ),
                    child: selected ? Text(
                      reference.image.path,
                      style: theme.textTheme.labelSmall,
                    ) : const SizedBox(),
                  ),
                ],
              ),
              const SizedBox(height: 8,),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  fixedCrossAxisSizeFactor: 1.0,
                  child: child,
                ),
                child: selected ? _BlendModeSelector(
                  reference: reference,
                ) : const SizedBox(),
              ),
              const SizedBox(height: 8,),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  fixedCrossAxisSizeFactor: 1.0,
                  child: child,
                ),
                child: selected ? Column(
                  children: [
                    Text("Opacity:", style: theme.textTheme.labelLarge,),
                    Slider(
                      value: reference.opacity,
                      onChangeStart: (_) {
                        reference.recordOpacityStart();
                      },
                      onChanged: (newOpacity) {
                        reference.updateOpacityIntermediate(newOpacity);
                      },
                      onChangeEnd: (_) {
                        reference.commitOpacity(history);
                      },
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: "${(reference.opacity * 100).floor()}%",
                    ),
                  ],
                ) : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlendModeSelector extends StatefulWidget {
  final Reference reference;

  const _BlendModeSelector({required this.reference});

  @override
  State<_BlendModeSelector> createState() => _BlendModeSelectorState();
}

class _BlendModeSelectorState extends State<_BlendModeSelector> {

  final FocusNode _focusNode = FocusNode(debugLabel: "BlendModeSelector");

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = HistoryManager.of(context);

    return Row(
      children: [
        Text("Blend mode:", style: theme.textTheme.labelLarge),
        const SizedBox(width: 8),
        DropdownButton<BlendMode>(
          value: widget.reference.blendMode,
          focusNode: _focusNode,
          onChanged: (newBlendMode) {
            setState(() {
              widget.reference.setBlendMode(history, newBlendMode ?? BlendMode.srcOver);
              _focusNode.unfocus();
            });
          },
          items: BlendMode.values.map((mode) {
            return DropdownMenuItem<BlendMode>(
              value: mode,
              child: Text(mode.toString().split('.').last),
            );
          }).toList(),
        ),
      ],
    );
  }
}