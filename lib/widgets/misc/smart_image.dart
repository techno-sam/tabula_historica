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
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:http/http.dart' as http;
import 'package:tabula_historica/util/string.dart';

import '../../extensions/numeric.dart';
import '../../logger.dart';

class SmartImage extends StatelessWidget {
  final Uri url;

  const SmartImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.host == "commons.wikimedia.org" && url.path.startsWith("/wiki/File:")) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return _WikimediaImage(
            url: url,
            constraints: constraints,
          );
        },
      );
    } else {
      return Image.network(
        url.toString(),
        fit: BoxFit.contain,
      );
    }
  }
}

class _WikimediaImage extends StatefulWidget {
  const _WikimediaImage._({
    super.key,
    required this.url,
    required this.constraints,
  });

  factory _WikimediaImage({required Uri url, required BoxConstraints constraints}) {
    return _WikimediaImage._(
      key: ValueKey(url),
      url: url,
      constraints: constraints,
    );
  }

  final Uri url;
  final BoxConstraints constraints;

  @override
  State<_WikimediaImage> createState() => _WikimediaImageState();
}

class _WikimediaImageState extends State<_WikimediaImage> {
  Point<double>? _lastConstraints;
  Image? _lastFetched;
  bool _lastValid = true;

  @override
  Widget build(BuildContext context) {
    logger.t("Building Wikimedia image: ${widget.url}");
    if (_lastConstraints != null) {
      logger.t("Last constraints: ${widget.constraints}");
      if (_lastConstraints!.x != widget.constraints.maxWidth ||
          _lastConstraints!.y != widget.constraints.maxHeight) {
        logger.t("Constraints changed, resetting image");
        _lastValid = false;
      }
    }
    _lastConstraints = Point(widget.constraints.maxWidth, widget.constraints.maxHeight);
    if (_lastFetched != null && _lastValid) {
      logger.t("Returning last fetched image");
      return _lastFetched!;
    }
    return FutureBuilder<Image>(
      future: _fetchWikimediaImage(widget.url.toString(), width: widget.constraints.maxWidth.infiniteToNull(), height: widget.constraints.maxHeight.infiniteToNull()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_lastFetched != null) {
            logger.t("Returning last with loading");
            return Stack(
              children: [
                Center(child: _lastFetched!),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          }
          logger.t("Returning loading");
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Icon(Icons.error, color: Colors.red);
        } else if (snapshot.hasData) {
          logger.t("Returning fetched image");
          _lastFetched = snapshot.data;
          _lastValid = true;
          return snapshot.data!;
        } else {
          return const Icon(Icons.broken_image, color: Colors.grey);
        }
      },
    );
  }
}

/// Fetches the direct image URL from a Wikimedia Commons file info page based on the specified constraints.
Future<Image> _fetchWikimediaImage(String fileInfoUrl, {double? width, double? height}) async {
  try {
    // Extract the file name from the URL
    final fileName = Uri.decodeFull(fileInfoUrl.split("/wiki/File:").last);

    // Build the query parameters
    final params = {
      'action': 'query',
      'titles': 'File:$fileName',
      'prop': 'imageinfo',
      'iiprop': 'url|size',
      'format': 'json',
      if (width != null) 'iiurlwidth': width.toInt().toString(),
      if (width == null && height != null) 'iiurlheight': height.toInt().toString(),
    };

    logger.d("Fetching Wikimedia image: ${prettyEncoder.convert(params)}");

    // Make the API request
    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', params);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final pages = jsonData['query']['pages'] as Map<String, dynamic>;

      for (final page in pages.values) {
        final imageInfo = page['imageinfo'] as List<dynamic>?;
        if (imageInfo != null && imageInfo.isNotEmpty) {
          final imageUrl = imageInfo[0]['thumburl'];
          return Image.network(
            key: ValueKey((imageUrl, width, height)),
            imageUrl,
            width: width,
            height: height,
            fit: BoxFit.contain,
          );
        }
      }
    }
    throw Exception("Failed to fetch image URL");
  } catch (e) {
    logger.e("Error fetching Wikimedia image: $e");
    rethrow;
  }
}
