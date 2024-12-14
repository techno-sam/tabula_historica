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
import 'package:provider/provider.dart';
import 'package:tabula_historica/main.dart';
import 'package:tabula_historica/models/project/project.dart';

import '../../misc/simple_editable_text.dart';
import '../../../logger.dart';
import '../../../models/project/history_manager.dart';
import '../../../models/project/reference.dart';
import '../../../models/tools/references_state.dart';
import '../../../models/tools/tool_selection.dart';

class ReferenceListTile extends StatelessWidget {
  final Reference reference;
  final int index;

  const ReferenceListTile({super.key, required this.reference, required this.index});

  @override
  Widget build(BuildContext context) {
    timeDilation = 1.0;
    final theme = Theme.of(context);
    final toolSelection = ToolSelection.of(context);
    final history = HistoryManager.of(context);

    final selected = toolSelection.selectedTool == Tool.references &&
        toolSelection.mapStateOr((ReferencesState state) =>
            state.isReferenceSelected(reference), false);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: selected ? Colors.blue : theme.colorScheme.onSurface.withOpacity(0.3),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: selected
                        ? SimpleEditableText(
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.file(
                    reference.image.toFile(),
                    width: 180,
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
              )
            ],
          ),
        ),
      ),
    );
  }
}