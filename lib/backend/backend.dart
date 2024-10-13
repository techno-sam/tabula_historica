import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LodEntry {
  final int minX;
  final int minZ;
  final int maxX;
  final int maxZ;

  LodEntry({required this.minX, required this.minZ, required this.maxX, required this.maxZ});
}

typedef LODs = Map<int, LodEntry>;

class Connection {
  final Uri apiUri;
  final http.Client _client = http.Client();

  Connection({required this.apiUri});

  Future<http.Response> get(Uri uri) async {
    var resolved = apiUri.resolveUri(uri);

    if (kDebugMode) {
      print("Resolved URI: $resolved");
    }

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
    ));
  }
}