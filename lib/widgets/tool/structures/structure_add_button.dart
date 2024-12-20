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

import '../../../logger.dart';
import '../../../models/project/project.dart';

class StructureAddButton extends StatefulWidget {
  const StructureAddButton({super.key});

  @override
  State<StructureAddButton> createState() => _StructureAddButtonState();
}

class _StructureAddButtonState extends State<StructureAddButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = Project.of(context);

    return OutlinedButton(
      onPressed: () {
        project.createStructure();
      },
      onHover: (isHovering) {
        setState(() {
          _isHovering = isHovering;
        });
      },
      style: OutlinedButton.styleFrom(
        elevation: _isHovering ? 2 : 0,
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4.0)),
          side: BorderSide(color: Colors.grey),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.add_home_outlined,
                color: _isHovering ? Colors.blue : theme.iconTheme.color,
              ),
              Text(
                "New Structure",
                style: (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                  color: _isHovering ? Colors.blue : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}