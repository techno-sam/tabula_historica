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
import 'package:tabula_historica/extensions/color_manipulation.dart';
import 'package:tabula_historica/widgets/providers/keyboard_event.dart';
import '../widgets/map/multi_lod.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);

    return Scaffold(
      /*appBar: AppBar(
        backgroundColor: theme.colorScheme.secondary,
        title: const Text('Demo Map'),
      ),*/
      backgroundColor: const Color(0xFFFCF5E5).lighten(0.025), // parchment
      body: const KeyboardEventProvider(child: MultiLODMap()),
    );
  }
}
