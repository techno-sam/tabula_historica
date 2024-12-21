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

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_scroll_shadow/flutter_scroll_shadow.dart';
import 'package:provider/provider.dart';
import 'package:tabula_historica/widgets/tool/structures/structure_add_button.dart';

import '../../../logger.dart';
import '../../../models/project/history_manager.dart';
import '../../../models/project/project.dart';
import '../../../models/tools/structures_state.dart';
import '../../../models/tools/tool_selection.dart';
import '../../misc/scroll_shadow_axis_limiter.dart';
import '../tool_specific.dart';
import 'structure_sidebar_tile.dart';

class StructureSidebar extends StatelessWidget {
  const StructureSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolSpecificEphemeral(
      tool: Tool.structures,
      builder: (context) {
        return Positioned(
          top: 8,
          left: 8,
          bottom: 8,
          width: 350,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (details.localPosition.dy < 45) {
                final toolSelection = ToolSelection.of(context, listen: false);
                toolSelection.withState((StructuresState state) {
                  state.deselect();
                });
              }
            },
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              color: theme.colorScheme.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      "Structures",
                      style: theme.textTheme.titleLarge,
                    ),
                    SizedBox(height: ((theme.dividerTheme.space ?? 16) - (theme.dividerTheme.thickness ?? 0)) / 2),
                    Divider(
                      height: theme.dividerTheme.thickness ?? 0,
                      thickness: theme.dividerTheme.thickness ?? 0,
                    ),
                    const Expanded(
                      child: _StructureList(),
                    ),
                    Divider(
                      height: theme.dividerTheme.thickness ?? 0,
                      thickness: theme.dividerTheme.thickness ?? 0,
                    ),
                    const StructureAddButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StructureList extends StatelessWidget {
  const _StructureList({
    // ignore: unused_element
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = HistoryManager.of(context);
    final structureList = StructureList.of(context);

    return ScrollShadow(
      color: (theme.dividerTheme.color ?? theme.colorScheme.outlineVariant).withValues(alpha: 0.8),
      child: ScrollShadowAxisLimiter(
        axis: Axis.vertical,
        child: ReorderableListView.builder(
          restorationId: "structure_list",
          itemBuilder: (context, index) {
            final structure = structureList[index];
            if (index == structureList.length - 1) {
              return ChangeNotifierProvider.value(
                key: ObjectKey(structure.uuid),
                value: structure,
                child: StructureListTile(
                  index: index,
                ),
              );
            }
            return DecoratedBox(
              key: ObjectKey(structure.uuid),
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border(
                  bottom: Divider.createBorderSide(context),
                ),
              ),
              child: Column(
                children: [
                  ChangeNotifierProvider.value(
                    value: structure,
                    child: StructureListTile(
                      index: index,
                    ),
                  ),
                  const SizedBox(height: 1),
                ],
              ),
            );
          },
          itemCount: structureList.length,
          buildDefaultDragHandles: false,
          onReorder: (int oldIndex, int newIndex) {
            logger.d("Reordering structures from $oldIndex to $newIndex");
            structureList.reorder(history, oldIndex, newIndex);
          },
          proxyDecorator: (child, index, animation) {
            final toolSelection = ToolSelection.of(context, listen: false);
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                final double animValue = Curves.easeInOut.transform(animation.value);
                final double elevation = lerpDouble(0, 6, animValue)!;
                return Material(
                  elevation: elevation,
                  child: MultiProvider(
                    providers: [
                      ChangeNotifierProvider.value(value: history),
                      ChangeNotifierProvider.value(value: toolSelection),
                    ],
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
        ),
      ),
    );
  }
}
