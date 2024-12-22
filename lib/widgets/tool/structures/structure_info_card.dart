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
import 'package:provider/provider.dart';
import 'package:tabula_historica/models/tools/structures_state.dart';

import '../../../extensions/color_manipulation.dart';
import '../../../extensions/numeric.dart';
import '../../../models/project/structure.dart';
import '../../../models/tools/tool_selection.dart';
import '../../misc/smart_image.dart';

class StructureInfoCard extends StatelessWidget {
  const StructureInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final structure = context.watch<Structure>();

    return SizedBox(
      width: 350.0,
      child: Card.outlined(
        color: theme.colorScheme.surfaceContainerLowest,
        // black outline
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(
            color: theme.colorScheme.surfaceContainerLowest.invert(),
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 4.0, horizontal: 8.0),
          child: Column(
            children: [
              Text(
                structure.titleForDisplayNoSubtitle,
                style: theme.textTheme.titleLarge,
              ),
              if (structure.titleForDisplaySubtitle != null)
                Text(
                  structure.titleForDisplaySubtitle!,
                  style: theme.textTheme.titleMedium,
                ),
              if (structure.hasInfo)
                const Divider(),
              if (structure.imageURL != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                  child: SmartImage(url: structure.imageURL!),
                ),
              if (structure.builtYear != null)
                _LabeledRow(
                  label: 'Built',
                  value: structure.builtYear!.yearDateToString(),
                ),
              if (structure.builtBy != null)
                _LabeledRow(
                  label: 'Built by',
                  value: structure.builtBy!,
                ),
              if (structure.destroyedYear != null)
                _LabeledRow(
                  label: 'Destroyed',
                  value: structure.destroyedYear!.yearDateToString(),
                ),
              if (structure.destroyedBy != null)
                _LabeledRow(
                  label: 'Destroyed by',
                  value: structure.destroyedBy!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final String value;

  const _LabeledRow({required this.label, required this.value});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(width: 8.0),
          Flexible(
            flex: 11,
            fit: FlexFit.tight,
            child: Text(
              value,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class StructureInfoCardDebugDisplay extends StatelessWidget {
  const StructureInfoCardDebugDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final toolSelection = ToolSelection.of(context);

    Structure? selected = toolSelection.mapState<Structure?, StructuresState>((StructuresState state) => state.selectedStructure);
    if (selected == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 4.0,
      right: 4.0,
      child: ChangeNotifierProvider.value(
        value: selected,
        child: const StructureInfoCard(),
      ),
    );
  }
}
