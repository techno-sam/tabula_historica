import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:track_map/backend/backend.dart' as backend;
import 'package:track_map/extensions/color_manipulation.dart';

const int tileSize = 256;

class MultiLODMap extends StatelessWidget {
  const MultiLODMap({super.key});

  @override
  Widget build(BuildContext context) {
    final client = context.watch<backend.Connection>();

    return FutureBuilder(
      future: client.getLODs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        var lods = snapshot.data;
        if (lods == null) {
          return const Text('Null data');
        }

        return Center(
          child: _MultiLODMap(lods: lods),
        );
      }
    );
  }
}

double log2(num x) => log(x) / ln2;

class LODCalculator {
  final int minLOD;
  final int maxLOD;

  LODCalculator._({required this.minLOD, required this.maxLOD});

  factory LODCalculator({required backend.LODs lods}) {
    int minLOD = lods.keys.reduce((value, element) => value < element ? value : element);
    int maxLOD = lods.keys.reduce((value, element) => value > element ? value : element);

    // assert that all intermediate LODs are present
    for (int i = minLOD; i <= maxLOD; i++) {
      assert(lods.containsKey(i));
    }

    return LODCalculator._(minLOD: minLOD, maxLOD: maxLOD);
  }

  (double, int) getLod(double scale) {
    int lodScale = (scale+0.1).round().clamp(minLOD, maxLOD);
    //lodScale = maxLOD;
    int lod = (maxLOD - lodScale) + minLOD;
    double adjustedScale = pow(2, scale - lodScale).toDouble();
    return (adjustedScale, lod);
  }
}

class _MultiLODMap extends StatefulWidget {

  final backend.LODs lods;
  final LODCalculator lodCalculator;

  _MultiLODMap({super.key, required this.lods}) : lodCalculator = LODCalculator(lods: lods);

  @override
  State<_MultiLODMap> createState() => _MultiLODMapState();
}

class _MultiLODMapState extends State<_MultiLODMap> {
  final int _seed = Random().nextDouble().hashCode;

  double _centerX = 0; // block position
  double _centerZ = 0; // block position
  double _scale = log2(3/4);

  double get _uiInteractionScale => pow(2, _scale).toDouble();
  
  void _applyScaleChange(double dScale, Offset center, Size windowSize) {
    setState(() {
      double xUnderCursor = _centerX + (center.dx - windowSize.width/2) / (tileSize * _uiInteractionScale);
      double zUnderCursor = _centerZ + (center.dy - windowSize.height/2) / (tileSize * _uiInteractionScale);

      _scale += dScale;
      _scale = _scale.clamp(log2(1/16), log2(64));

      //print("Scale: $_scale");

      _centerX = xUnderCursor - (center.dx - windowSize.width/2) / (tileSize * _uiInteractionScale);
      _centerZ = zUnderCursor - (center.dy - windowSize.height/2) / (tileSize * _uiInteractionScale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return _build(context, Size(constraints.maxWidth, constraints.maxHeight));
    });
  }

  Widget _build(BuildContext context, Size size) {
    final (double adjustedScale, int lod) = widget.lodCalculator.getLod(_scale);
    final double unadjustedScale = _uiInteractionScale;

    //final Random random = Random(_seed);

    // transform so that the (_centerX, _centerZ) block position is in the center of the screen, taking _scale into account
    final double offsetX = size.width / 2 - _centerX * tileSize * unadjustedScale;
    final double offsetY = size.height / 2 - _centerZ * tileSize * unadjustedScale;
    
    List<Widget> tiles = [];

    for (int x = widget.lods[lod]!.minX; x <= widget.lods[lod]!.maxX; x++) {
      for (int z = widget.lods[lod]!.minZ; z <= widget.lods[lod]!.maxZ; z++) {
        double left = x * tileSize * adjustedScale + offsetX;
        double top = z * tileSize * adjustedScale + offsetY;
        double width = tileSize * adjustedScale;
        double height = tileSize * adjustedScale;

        // add a tile if this would be visible
        if (left + width >= 0 && left <= size.width && top+height >= 0 && top <= size.height) {
          tiles.add(Positioned(
            key: ValueKey(("map_tile", lod, x, z)),
            left: left.floorToDouble(),
            top: top.floorToDouble(),
            width: width.ceilToDouble(),
            height: height.ceilToDouble(),
            child: _MapTile(lod: lod, x: x, z: z)/*Container(
              color: Colors.primaries.choose(random),
              child: _MapTile(lod: lod, x: x, z: z),
            ),*/
          ));

          tiles.add(
            Positioned(
              key: ValueKey(("map_tile_text", lod, x, z)),
              left: left.floorToDouble(),
              top: top.floorToDouble(),
              width: width.ceilToDouble(),
              height: height.ceilToDouble(),
              child: Center(
                child: Text(
                  'LOD $lod\n($x, $z)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ),
            ),
          );
        }
      }
    }

    //print("Tile count: ${tiles.length}");

    /*tiles.add(Positioned(
      left: 0,
      top: 0,
      width: size.width,
      height: size.height,
      child: Container(
        color: Colors.cyanAccent.withOpacity(0.5),
        child: const Center(
          child: Placeholder()
        )
      ),
    ));*/

    return Listener(
      onPointerMove: (details) {
        if (details.down) {
          setState(() {
            _centerX -= details.delta.dx / (tileSize * unadjustedScale);
            _centerZ -= details.delta.dy / (tileSize * unadjustedScale);
          });
        }
      },
      onPointerSignal: (details) {
        if (details is PointerScrollEvent) {
          _applyScaleChange(-details.scrollDelta.dy / 300, details.position, size);
        }
      },
      onPointerPanZoomUpdate: (details) {
        _applyScaleChange(details.panDelta.dy / 100, details.localPosition, size);
      },
      child: Stack(
        children: [
          Container(
            color: Colors.indigo.darken(0.35),
            child: SizedBox(
              width: size.width,
              height: size.height,
            )
          ),
          ...tiles
        ],
      )
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile({
    super.key,
    required this.lod,
    required this.x,
    required this.z,
  });

  final int lod;
  final int x;
  final int z;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      key: ValueKey(("map_tile_image", lod, x, z)),
      'http://localhost:80/map_data/$lod/x$x/z$z.png',
      width: tileSize.toDouble(),
      height: tileSize.toDouble(),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      cacheWidth: tileSize,
      cacheHeight: tileSize,
      isAntiAlias: false,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        } else {
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
              color: Colors.green,
            ),
          );
          /*return const Center(
            child: Placeholder(color: Colors.green),
          );*/
        }
      },
      errorBuilder: (context, error, stackTrace) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Flexible(child: Text('Error loading tile: $error', style: const TextStyle(color: Colors.red))),
          ],
        );
      }
    );
  }
}