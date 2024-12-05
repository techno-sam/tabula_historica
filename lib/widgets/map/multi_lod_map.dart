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

part of 'multi_lod.dart';

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
          'User-Agent', () => 'tabula_historica ($userAgentPackageName)');
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
    final double offsetX = projected.x + (_debugPadding??0);//camera.size.width / 2 - camera.blockPosCenter.x * widget.tileSize * unadjustedScale;
    final double offsetY = projected.y + (_debugPadding??0);//camera.size.height / 2 - camera.blockPosCenter.y * widget.tileSize * unadjustedScale;

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
