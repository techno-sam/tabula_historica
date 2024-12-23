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
import '../../models/project/project.dart';
import '../tool/references/map_surface_reference.dart';

class AllReferences extends StatelessWidget {
  const AllReferences({super.key});

  @override
  Widget build(BuildContext context) {
    final references = ReferenceList.of(context);

    return Stack(children: [
      const Center(child: SizedBox.shrink()),
      ...references.referencesReversed.map((reference) {
        return ChangeNotifierProvider.value(
          key: ObjectKey(reference.uuid),
          value: reference,
          child: const MapTransformableReference(),
        );
      })
    ]);
  }
}