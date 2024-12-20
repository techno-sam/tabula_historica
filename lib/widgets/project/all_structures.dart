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
import 'package:tabula_historica/widgets/tool/structures/map_surface_structure.dart';

import '../../models/project/project.dart';

class AllStructures extends StatelessWidget {
  const AllStructures({super.key});

  @override
  Widget build(BuildContext context) {
    final structures = StructureList.of(context);

    return Stack(children: structures.structuresReversed.map((structure) {
      return ChangeNotifierProvider.value(
        key: ObjectKey(structure.uuid),
        value: structure,
        child: const MapSurfaceStructure(),
      );
    }).toList(growable: false));
  }
}