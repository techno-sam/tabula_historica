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
import 'package:tabula_historica/extensions/string.dart';

import '../../../models/project/structure.dart';
import 'structure_pen_selector.dart';

class PenKey extends StatelessWidget {
  final List<Widget> extraWidgets;

  const PenKey({super.key, this.extraWidgets = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.outlined(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: SizedBox(
          width: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final pen in Pen.displayValues)
                _PenDisplay(pen: pen),
              ...extraWidgets
            ],
          ),
        ),
      ),
    );
  }
}

class _PenDisplay extends StatelessWidget {
  final Pen pen;

  const _PenDisplay({required this.pen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          PenPreview(
            width: Width.normal,
            color: pen.color,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            pen.name.toTitleCase(),
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
