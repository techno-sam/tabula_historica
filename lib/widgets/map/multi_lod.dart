/*
 * Doodle Tracks
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

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:track_map/backend/backend.dart' as backend;
import 'package:track_map/logger.dart';
import 'package:track_map/widgets/map/flutter_map/map_camera.dart';
import 'package:track_map/widgets/map/flutter_map/providers/cancellable/cancellable_network_tile_provider.dart';
import 'package:track_map/widgets/map/flutter_map/providers/regular/network_tile_provider.dart';
import 'package:track_map/widgets/map/flutter_map/tile.dart';
import 'package:track_map/widgets/map/flutter_map/tile_bounds_at_zoom.dart';
import 'package:track_map/widgets/map/flutter_map/tile_coordinates.dart';
import 'package:track_map/widgets/map/flutter_map/tile_image.dart';
import 'package:track_map/widgets/map/flutter_map/tile_image_manager.dart';
import 'package:track_map/widgets/map/flutter_map/tile_range.dart';
import 'package:track_map/widgets/map/flutter_map/tile_range_calculator.dart';
import 'package:track_map/widgets/map/flutter_map/tile_builder.dart' as tile_builder;

import 'flutter_map/base_tile_provider.dart';
import 'flutter_map/tile_builder.dart';
import 'flutter_map/tile_error_evict_callback.dart';
import 'flutter_map/tile_update_event.dart';

const double? debugPadding = null;

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
          child: CameraProvider(
            child: _MapController(
              child: Stack(
                children: [
                  if (debugPadding != null)
                    Padding(
                        padding: EdgeInsets.all(debugPadding!),
                        child: Container(
                            color: Colors.black.withOpacity(0.5),
                            child: const SizedBox.expand()
                        )
                    ),
                  _MultiLODMap(
                    lods: lods,
                    tileProvider: CancellableNetworkTileProvider(),
                    tileBuilder: tile_builder.coordinateAndLoadingTimeDebugTileBuilder,
                    errorImage: const NetworkImage("https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQJO3ByBfWNJI8AS-m8MhsEZ65z5Wv2mnD5AQ&s"),
                    evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
                  ),
                ]
              ),
            )
          ),
        );
      }
    );
  }
}

class CameraProvider extends SingleChildStatefulWidget {
  const CameraProvider({super.key, super.child});

  @override
  State<CameraProvider> createState() => _CameraProviderState();
}

class _CameraProviderState extends SingleChildState<CameraProvider> {

  late final MapCamera _camera;

  bool _initialized = false;

  @override
  void dispose() {
    super.dispose();

    if (_initialized) {
      _initialized = false;
      _camera.dispose();
    }
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!_initialized) {
          _camera = MapCamera(
            blockPosCenter: const Point(0, 0),
            zoom: log2(3/4),
            size: Size(constraints.maxWidth - (debugPadding??0)*2, constraints.maxHeight - (debugPadding??0)*2)
          );
          _initialized = true;
        } else {
          _camera.size = Size(constraints.maxWidth - (debugPadding??0)*2, constraints.maxHeight - (debugPadding??0)*2);
        }

        return ChangeNotifierProvider.value(value: _camera, child: child);
      },
    );
  }
}

class _MapController extends SingleChildStatelessWidget {

  final int tileSize;

  const _MapController({
    super.key,
    super.child,
    this.tileSize = 256,
  });

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    final camera = MapCamera.of(context, listen: false);

    void $applyScaleChange(double dScale, Offset center, Size windowSize) {
      
      if (debugPadding != null) {
        center = Offset(center.dx - debugPadding!, center.dy - debugPadding!);
      }

      double centerX = camera.blockPosCenter.x;
      double centerZ = camera.blockPosCenter.y;
      double scale = camera.zoom;
      double uiInteractionScale = pow(2, scale).toDouble();

      double xUnderCursor = centerX + (center.dx - windowSize.width / 2) /
          (tileSize * uiInteractionScale);
      double zUnderCursor = centerZ + (center.dy - windowSize.height / 2) /
          (tileSize * uiInteractionScale);

      scale += dScale;
      scale = scale.clamp(log2(1 / 8), log2(128));

      uiInteractionScale = pow(2, scale).toDouble();

      //print("Scale: $_scale");

      centerX = xUnderCursor - (center.dx - windowSize.width / 2) /
          (tileSize * uiInteractionScale);
      centerZ = zUnderCursor - (center.dy - windowSize.height / 2) /
          (tileSize * uiInteractionScale);

      camera.asBatchOperation(() {
        camera.blockPosCenter = Point(centerX, centerZ);
        camera.zoom = scale;
      });
    }

    final List<Offset> communicatedCenter = [const Offset(0, 0)];

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey.keyLabel == "D") {
          // zoom to max zoom
          $applyScaleChange(1000, communicatedCenter[0], camera.size);
        }
      },
      child: Listener(
        onPointerHover: (details) {
          communicatedCenter[0] = details.localPosition;
        },
        onPointerMove: (details) {
          communicatedCenter[0] = details.localPosition;
          if (details.down) {
            double unadjustedScale = pow(2, camera.zoom).toDouble();
            Point<double> offset = Point(
              details.delta.dx / (tileSize * unadjustedScale),
              details.delta.dy / (tileSize * unadjustedScale)
            );
            camera.blockPosCenter = camera.blockPosCenter - offset;
          }
        },
        onPointerSignal: (details) {
          if (details is PointerScrollEvent) {
            $applyScaleChange(-details.scrollDelta.dy / 150, details.position, camera.size); // fixme should this use localPosition?
          }
        },
        onPointerPanZoomUpdate: (details) {
          $applyScaleChange(details.panDelta.dy / 100, details.localPosition, camera.size);
        },
        child: child
      ),
    );
  }

}

double log2(num x) => log(x) / ln2;

class LODCalculator {
  final int minLOD;
  final int maxLOD;

  LODCalculator._({required this.minLOD, required this.maxLOD});

  factory LODCalculator({required backend.LODs lods}) {
    return LODCalculator._(minLOD: lods.minLOD, maxLOD: lods.maxLOD);
  }

  double getAdjustedScale(double scale, int lodScale) {
    int clamped = lodScale.clamp(minLOD, maxLOD);
    return pow(2, scale - clamped).toDouble();
  }
  
  int getLodScale(double scale) => (scale + 0.1).round().clamp(minLOD, maxLOD);

  (double, int) getLod(double scale) {
    int lod = getLodScale(scale);
    double adjustedScale = getAdjustedScale(scale, lod);
    return (adjustedScale, lod);
  }
}

class _MultiLODMap extends StatefulWidget {

  final backend.LODs lods;

  /// Size for the tile.
  /// Default is 256
  final double tileSize;

  /// Provider with which to load map tiles
  ///
  /// The default is [NetworkTileProvider] which supports both IO and web
  /// platforms, with basic session-only caching. It uses a [RetryClient] backed
  /// by a standard [Client] to retry failed requests.
  ///
  /// `userAgentPackageName` is a [TileLayer] parameter, which should be passed
  /// the application's correct package name, such as 'com.example.app'. See
  /// https://docs.fleaflet.dev/layers/tile-layer#useragentpackagename for
  /// more information.
  ///
  /// For information about other prebuilt tile providers, see
  /// https://docs.fleaflet.dev/layers/tile-layer/tile-providers.
  final TileProvider tileProvider;

  /// When panning the map, keep this many rows and columns of tiles before
  /// unloading them.
  final int keepBuffer;

  /// When loading tiles only visible tiles are loaded by default. This option
  /// increases the loaded tiles by the given number on both axis which can help
  /// prevent the user from seeing loading tiles whilst panning. Setting the
  /// pan buffer too high can impact performance, typically this is set to zero
  /// or one.
  final int panBuffer;

  /// Tile image to show in place of the tile that failed to load.
  final ImageProvider? errorImage;

  /// This callback will be executed if an error occurs when fetching tiles.
  final ErrorTileCallBack? errorTileCallback;

  /// Function which may Wrap Tile with custom Widget
  /// There are predefined examples in 'tile_builder.dart'
  final TileBuilder? tileBuilder;

  /// If a Tile was loaded with error and if strategy isn't `none` then TileProvider
  /// will be asked to evict Image based on current strategy
  /// (see #576 - even Error Images are cached in flutter)
  final EvictErrorTileStrategy evictErrorTileStrategy;

  _MultiLODMap({
    super.key,
    required this.lods,
    this.tileSize = 256,
    this.keepBuffer = 2,
    this.panBuffer = 1,
    this.errorImage,
    final TileProvider? tileProvider,
    this.errorTileCallback,
    this.tileBuilder,
    this.evictErrorTileStrategy = EvictErrorTileStrategy.none,
    String userAgentPackageName = 'unknown',
  }) : tileProvider = tileProvider ?? NetworkTileProvider() {
    // Tile Provider Setup
    if (!kIsWeb) {
      this.tileProvider.headers.putIfAbsent(
          'User-Agent', () => 'doodle_tracks ($userAgentPackageName)');
    }
  }

  @override
  State<_MultiLODMap> createState() => _MultiLODMapState();
}

class _MultiLODMapState extends State<_MultiLODMap> {
  bool _initializedFromMapCamera = false;

  final _tileImageManager = TileImageManager();
  late final LODCalculator lodCalculator;
  late TileRangeCalculator _tileRangeCalculator;

  StreamSubscription<TileUpdateEvent>? _tileUpdateSubscription;

  Set<TileCoordinates> _displayedTiles = {};

  @override
  void initState() {
    super.initState();
    lodCalculator = LODCalculator(lods: widget.lods);
    _tileRangeCalculator = TileRangeCalculator(
        tileSize: widget.tileSize, lodCalculator: lodCalculator);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final camera = MapCamera.of(context, listen: false);

    if (!_initializedFromMapCamera) {
      _tileUpdateSubscription = camera.updateStream.listen(_onTileUpdateEvent);

      _loadAndPruneInVisibleBounds(camera);
      _initializedFromMapCamera = true;
    }
  }

  @override
  void didUpdateWidget(covariant _MultiLODMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    _tileRangeCalculator = TileRangeCalculator(
        tileSize: widget.tileSize, lodCalculator: lodCalculator);
  }

  @override
  void dispose() {
    _tileUpdateSubscription?.cancel();
    _tileImageManager.removeAll(widget.evictErrorTileStrategy);
    widget.tileProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    final (double adjustedScale, int lod) = lodCalculator.getLod(camera.zoom);
    //final double unadjustedScale = pow(2, camera.zoom).toDouble();

    var projected = camera.getOffset(const Point(0, 0));
    // transform so that the (_centerX, _centerZ) block position is in the center of the screen, taking _scale into account
    final double offsetX = projected.x + (debugPadding??0);//camera.size.width / 2 - camera.blockPosCenter.x * widget.tileSize * unadjustedScale;
    final double offsetY = projected.y + (debugPadding??0);//camera.size.height / 2 - camera.blockPosCenter.y * widget.tileSize * unadjustedScale;

    //print("Camera: ${camera.blockPosCenter}, ${camera.zoom}");
    //print("Size: ${camera.size}");
    //print("Projected: $projected");

    final visibleTileRange = _tileRangeCalculator.calculate(
        camera: camera, tileLOD: lod);

    // For a given map event both this rebuild method and the tile
    // loading/pruning logic will be fired. Any TileImages which are not
    // rendered in a corresponding Tile after this build will not become
    // visible until the next build. Therefore, in case this build is executed
    // before the loading/updating, we must pre-create the missing TileImages
    // and add them to the widget tree so that when they are loaded they notify
    // the Tile and become visible. We don't need to prune here as any new tiles
    // will be pruned when the map event triggers tile loading.
    var tileBoundsAtZoom = LODEntryBasedTileBoundsAtZoom(entry: widget.lods[lod]!);
    _tileImageManager.createMissingTiles(
      visibleTileRange,
      tileBoundsAtZoom,
      createTile: (coordinates) =>
          _createTileImage(
            coordinates: coordinates,
            tileBoundsAtZoom: tileBoundsAtZoom,
            pruneAfterLoad: false,
          ),
    );

    // Note: `renderTiles` filters out all tiles that are either off-screen or
    // tiles at non-target zoom levels that are would be completely covered by
    // tiles that are *ready* and at the target zoom level.
    // We're happy to do a bit of diligent work here, since tiles not rendered are
    // cycles saved later on in the render pipeline.
    final tiles = _tileImageManager
        .getTilesToRender(visibleRange: visibleTileRange)
        .map((tileRenderer) =>
        Tile(
          // Must be an ObjectKey, not a ValueKey using the coordinates, in
          // case we remove and replace the TileImage with a different one.
          key: ObjectKey(tileRenderer),
          scaledTileSize: widget.tileSize * lodCalculator.getAdjustedScale(
              camera.zoom, tileRenderer.coordinates.lod), /*_tileScaleCalculator.scaledTileSize(
          map.zoom,
          tileRenderer.positionCoordinates.z,
        ),*/
          currentPixelOffset: Point(offsetX, offsetY),
          tileImage: tileRenderer,
          tileBuilder: widget.tileBuilder,
        ))
        .toList();

    _displayedTiles = tiles.map((t) => t.positionCoordinates).toSet();

    if (tiles.isNotEmpty) {
      int minimalFoundLOD = tiles.map((t) => t.tileImage.coordinates.lod)
          .reduce(min);
      int maximalFoundLOD = tiles.map((t) => t.tileImage.coordinates.lod)
          .reduce(max);

      logger.t("LOD: $lod, min $minimalFoundLOD, max $maximalFoundLOD");
    }

    // Sort in render order. In reverse:
    //   1. Tiles at the current zoom.
    //   2. Tiles at the current zoom +/- 1.
    //   3. Tiles at the current zoom +/- 2.
    //   4. ...etc
    int renderOrder(Tile a, Tile b) {
      final (lodA, lodB) = (a.tileImage.coordinates.lod, b.tileImage.coordinates.lod);
      final cmp = (lodB - lod).abs().compareTo((lodA - lod).abs());
      if (cmp == 0) {
        // When compare parent/child tiles of equal distance, prefer higher res images.
        return lodA.compareTo(lodB);
      }
      return cmp;
    }

    return Stack(children: [
      Stack(children: tiles..sort(renderOrder)),
      ElevatedButton.icon(onPressed: () {
        _tileImageManager.clearAllTiles();
        //_loadAndPruneInVisibleBounds(camera);
        setState(() {});
      }, icon: const Icon(Icons.refresh), label: const Text("Reload")),
    ]);
  }

  TileImage _createTileImage({
    required TileCoordinates coordinates,
    required TileBoundsAtZoom tileBoundsAtZoom,
    required bool pruneAfterLoad,
  }) {
    final cancelLoading = Completer<void>();

    final imageProvider = widget.tileProvider.supportsCancelLoading
        ? widget.tileProvider.getImageWithCancelLoadingSupport(coordinates, cancelLoading.future)
        : widget.tileProvider.getImage(coordinates);

    return TileImage(
      coordinates: coordinates,
      imageProvider: imageProvider,
      onLoadError: _onTileLoadError,
      onLoadComplete: (coordinates) {
        if (pruneAfterLoad) _pruneIfAllVisibleTilesLoaded(coordinates);
      },
      errorImage: widget.errorImage,
      cancelLoading: cancelLoading,
    );
  }

  void _rebuildIfDisplayedTilesPruned(Iterable<TileCoordinates> prunedTiles) {
    if (prunedTiles.any(_displayedTiles.contains)) {
      logger.t("Rebuilding due to pruned tiles");
      _displayedTiles.clear();
      setState(() {});
    }
  }

  /// Load and/or prune tiles according to the visible bounds of the [event]
  /// center/zoom, or the current center/zoom if not specified.
  void _onTileUpdateEvent(TileUpdateEvent event) {
    int tileLOD = lodCalculator.getLod(event.camera.zoom).$2;

    final visibleTileRange = _tileRangeCalculator.calculate(
      camera: event.camera,
      tileLOD: tileLOD,
    );

    if (event.load) {
      _loadTiles(visibleTileRange, tileLOD, pruneAfterLoad: event.prune);
    }

    if (event.prune) {
      _rebuildIfDisplayedTilesPruned(_tileImageManager.evictAndPrune(
        visibleRange: visibleTileRange,
        pruneBuffer: widget.panBuffer + widget.keepBuffer,
        evictStrategy: widget.evictErrorTileStrategy,
      ));
    }
  }

  /// Load new tiles in the visible bounds and prune those outside.
  void _loadAndPruneInVisibleBounds(MapCamera camera) {
    var tileLOD = lodCalculator.getLod(camera.zoom).$2;
    final visibleTileRange = _tileRangeCalculator.calculate(
      camera: camera,
      tileLOD: tileLOD,
    );

    _loadTiles(
      visibleTileRange,
      tileLOD,
      pruneAfterLoad: true,
    );


    _rebuildIfDisplayedTilesPruned(_tileImageManager.evictAndPrune(
      visibleRange: visibleTileRange,
      pruneBuffer: max(widget.panBuffer, widget.keepBuffer),
      evictStrategy: widget.evictErrorTileStrategy,
    ));
  }

  // For all valid TileCoordinates in the [tileLoadRange], expanded by the
  // [TileLayer.panBuffer], this method will do the following depending on
  // whether a matching TileImage already exists or not:
  //   * Exists: Mark it as current and initiate image loading if it has not
  //     already been initiated.
  //   * Does not exist: Creates the TileImage (they are current when created)
  //     and initiates loading.
  //
  // Additionally, any current TileImages outside of the [tileLoadRange],
  // expanded by the [TileLayer.panBuffer] + [TileLayer.keepBuffer], are marked
  // as not current.
  void _loadTiles(
      DiscreteTileRange tileLoadRange,
      int tileLOD, {
        required bool pruneAfterLoad,
      }) {
    final expandedTileLoadRange = tileLoadRange.expand(widget.panBuffer);
    
    // Build the queue of tiles to load. Marks all tiles with valid coordinates
    // in the tileLoadRange as current.
    var tileBoundsAtZoom = LODEntryBasedTileBoundsAtZoom(entry: widget.lods[tileLOD]!);
    final tilesToLoad = _tileImageManager.createMissingTiles(
      expandedTileLoadRange,
      tileBoundsAtZoom,
      createTile: (coordinates) => _createTileImage(
        coordinates: coordinates,
        tileBoundsAtZoom: tileBoundsAtZoom,
        pruneAfterLoad: pruneAfterLoad,
      ),
    );

    // Re-order the tiles by their distance to the center of the range.
    final tileCenter = expandedTileLoadRange.center;
    tilesToLoad.sort(
          (a, b) => _distanceSq(a.coordinates, tileCenter)
          .compareTo(_distanceSq(b.coordinates, tileCenter)),
    );

    // Create the new Tiles.
    for (final tile in tilesToLoad) {
      tile.load();
    }
  }

  void _onTileLoadError(TileImage tile, Object error, StackTrace? stackTrace) {
    logger.e("Failed to load tile", error: error);
    widget.errorTileCallback?.call(tile, error, stackTrace);
  }

  void _pruneIfAllVisibleTilesLoaded(TileCoordinates coordinates) {
    if (!_tileImageManager.containsTileAt(coordinates)) {
      return;
    }

    final camera = MapCamera.of(context, listen: false);
    final visibleTileRange = _tileRangeCalculator.calculate(
      camera: camera,
      tileLOD: lodCalculator.getLod(camera.zoom).$2,
    );

    if (!_tileImageManager.allVisibleTilesLoaded(visibleTileRange)) {
      return;
    }

    _pruneWithCurrentCamera(visibleTileRange);
  }

  void _pruneWithCurrentCamera(final DiscreteTileRange visibleTileRange) {
    _tileImageManager.prune(
      visibleRange: visibleTileRange,
      pruneBuffer: max(widget.panBuffer, widget.keepBuffer),
      evictStrategy: widget.evictErrorTileStrategy,
    );
    setState(() {});
  }
}

double _distanceSq(TileCoordinates coordinates, Point<double> center) {
  final dx = coordinates.x - center.x;
  final dy = coordinates.y - center.y;
  return dx * dx + dy * dy;
}
