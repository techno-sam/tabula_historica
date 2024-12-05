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

import 'dart:convert';

import 'package:http/http.dart' as http;
import '../logger.dart';
import '../widgets/map/data_structures.dart';
import '../widgets/map/flutter_map/tile_coordinates.dart';

class LodEntry {
  final int minX;
  final int minZ;
  final int maxX;
  final int maxZ;

  LodEntry({required this.minX, required this.minZ, required this.maxX, required this.maxZ});

  bool contains(TileCoordinates coordinates) {
    return coordinates.x >= minX && coordinates.x <= maxX && coordinates.y >= minZ && coordinates.y <= maxZ;
  }
}

typedef LODs = LODMap<LodEntry>;

class Connection {
  final Uri apiUri;
  final http.Client _client = http.Client();

  Connection({required this.apiUri});

  Future<http.Response> get(Uri uri) async {
    var resolved = apiUri.resolveUri(uri);

    logger.t("Resolved URI: $resolved");

    return _client.get(
      resolved
    );
  }

  Future<LODs> getLODs() async {
    final response = await get(Uri(path: 'lods.json'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load LOD data');
    }

    // Map<String, Map<String, int>>
    final Map<String, dynamic> jsonBody = jsonDecode(response.body);

    return jsonBody.map((key, value) => MapEntry(
        int.parse(key),
        LodEntry(
            minX: value['min_x']!,
            minZ: value['min_z']!,
            maxX: value['max_x']!,
            maxZ: value['max_z']!
        )
    )).toLODMap();
  }
}