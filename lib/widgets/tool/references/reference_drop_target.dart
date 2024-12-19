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

import 'dart:math';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../extensions/directory.dart';
import '../../../models/project/project.dart';
import '../../../logger.dart';

class ReferenceDropTarget extends StatefulWidget {
  const ReferenceDropTarget({super.key});

  @override
  State<ReferenceDropTarget> createState() => _ReferenceDropTargetState();
}

class _ReferenceDropTargetState extends State<ReferenceDropTarget> {

  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = Project.of(context);

    return DropTarget(
      onDragEntered: (details) {
        logger.t("Drag entered");
        setState(() {
          _isHovering = true;
        });
      },
      onDragExited: (details) {
        logger.t("Drag exited");
        setState(() {
          _isHovering = false;
        });
      },
      onDragDone: (details) async {
        logger.d("Dropped a number of files");
        final tmpDir = await getTemporaryDirectory();
        for (final item in details.files) {
          logger.d("Path ${item.path}, mime ${item.mimeType}, name ${item.name}");
          if (!item.name.endsWith(".png") && !item.name.endsWith(".jpg") && !item.name.endsWith(".jpeg")) {
            logger.d("Ignoring file ${item.name}");
            continue;
          }
          final tmpFile = tmpDir.resolveFile(item.name);
          await item.saveTo(tmpFile.path);

          final decoded = await decodeImageFromList(await item.readAsBytes());
          final dimensions = Point(decoded.width, decoded.height);
          logger.d("Dimensions $dimensions");
          await project.createReference(tmpFile, dimensions, "New reference");
          decoded.dispose();

          await tmpFile.delete();
        }
      },
      child: Card(
        elevation: _isHovering ? 2 : 0,
        color: theme.colorScheme.surfaceContainerLowest,
        margin: const EdgeInsets.only(top: 6.0),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4.0)),
          side: BorderSide(color: Colors.grey),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: _isHovering ? Colors.blue : theme.iconTheme.color,
                ),
                Text(
                  "Drop here",
                  style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                    color: _isHovering ? Colors.blue : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}