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

import '../../../models/project/history_manager.dart';
import '../../../models/project/project.dart';
import '../../../logger.dart';
import '../../../models/tools/tool_selection.dart';
import '../tool_specific.dart';
import 'reference_sidebar_tile.dart';

class ReferenceSidebar extends StatelessWidget {
  const ReferenceSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolSpecificEphemeral(
      tool: Tool.references,
      builder: (context) {
        return Positioned(
          top: 8,
          left: 8,
          bottom: 8,
          width: 250,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            child: Card(
              elevation: 1,
              color: theme.colorScheme.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      "References",
                      style: theme.textTheme.titleLarge,
                    ),
                    SizedBox(height: ((theme.dividerTheme.space ?? 16) - (theme.dividerTheme.thickness ?? 0)) / 2),
                    Divider(
                      height: theme.dividerTheme.thickness ?? 0,
                      thickness: theme.dividerTheme.thickness ?? 0,
                    ),
                    const Expanded(
                      child: _ReferenceList(),
                    ),
                    Divider(
                      height: theme.dividerTheme.thickness ?? 0,
                      thickness: theme.dividerTheme.thickness ?? 0,
                    ),
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

class _ReferenceList extends StatelessWidget {
  const _ReferenceList({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = HistoryManager.of(context);
    final referenceList = ReferenceList.of(context);

    return ScrollShadow(
      color: (theme.dividerTheme.color ?? theme.colorScheme.outlineVariant).withOpacity(0.8),
      child: ReorderableListView.builder(
        restorationId: "reference_list",
        itemBuilder: (context, index) {
          final reference = referenceList[index];
          if (index == referenceList.length - 1) {
            return ReferenceListTile(
              key: ObjectKey(reference.uuid),
              reference: reference,
              index: index,
            );
          }
          return DecoratedBox(
            key: ObjectKey(reference.uuid),
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border(
                bottom: Divider.createBorderSide(context),
              ),
            ),
            child: Column(
              children: [
                ReferenceListTile(
                  reference: reference,
                  index: index,
                ),
                const SizedBox(height: 1),
              ],
            ),
          );
        },
        itemCount: referenceList.length,
        buildDefaultDragHandles: false,
        onReorder: (int oldIndex, int newIndex) {
          logger.d("Reordering references from $oldIndex to $newIndex");
          referenceList.reorder(history, oldIndex, newIndex);
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
                child: ChangeNotifierProvider.value(
                  value: toolSelection,
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
      ),
    );
  }
}
