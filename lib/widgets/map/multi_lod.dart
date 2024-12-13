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

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:tabula_historica/widgets/project/all_references.dart';
import 'package:tabula_historica/widgets/tool/references/reference_sidebar.dart';
import 'package:tabula_historica/widgets/tool/tool_specific.dart';

import '../providers/project.dart';
import '../../util/math.dart';
import 'widgets/map_surface_positioned.dart';
import '../../extensions/pointer_event.dart';
import '../tool/toolbar.dart';
import '../../backend/backend.dart' as backend;
import '../../logger.dart';
import '../../models/tools/tool_selection.dart';
import 'flutter_map/map_camera.dart';

import 'flutter_map/extensions/point.dart';
import 'flutter_map/providers/cancellable/cancellable_network_tile_provider.dart';
import 'flutter_map/providers/regular/network_tile_provider.dart';
import 'flutter_map/tile.dart';
import 'flutter_map/tile_bounds_at_zoom.dart';
import 'flutter_map/tile_coordinates.dart';
import 'flutter_map/tile_image.dart';
import 'flutter_map/tile_image_manager.dart';
import 'flutter_map/tile_range.dart';
import 'flutter_map/tile_range_calculator.dart';
import 'flutter_map/tile_builder.dart' as tile_builder;
import 'flutter_map/base_tile_provider.dart';
import 'flutter_map/tile_builder.dart';
import 'flutter_map/tile_error_evict_callback.dart';
import 'flutter_map/tile_update_event.dart';

part 'multi_lod_map.dart';
part 'multi_lod_controller.dart';

const double? _debugPadding = null;


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

          final theme = Theme.of(context);

          return Center(
            child: MultiProvider(
              providers: [
                const _CameraProvider(),
                const _ToolSelectionProvider(),
                ProjectProvider(rootDir: Directory("/home/sam/AppDev/tabula_historica/projects/test_project"))
              ],
              child: Stack(
                children: [
                  _MapController(
                    child: Stack(
                        children: [
                          if (_debugPadding != null)
                            Padding(
                              padding: EdgeInsets.all(_debugPadding!),
                              child: Container(
                                color: Colors.black.withOpacity(0.5),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          _MultiLODMap(
                            lods: lods,
                            tileProvider: CancellableNetworkTileProvider(),
                            tileBuilder: tile_builder
                                .coordinateAndLoadingTimeDebugTileBuilder,
                            errorImage: const NetworkImage(
                                "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQJO3ByBfWNJI8AS-m8MhsEZ65z5Wv2mnD5AQ&s"),
                            evictErrorTileStrategy: EvictErrorTileStrategy
                                .notVisibleRespectMargin,
                          ),
                          /******************************/
                          /* Surface positioned widgets */
                          /******************************/
                          //const DebugMapSurfacePositioned(x: -32, y: 16, baseScale: 1, which: false),
                          MapSurfacePositioned(
                              x: -32, y: 16, baseScale: 1, child: ElevatedButton(
                            onPressed: () {
                              logger.i("Button pressed");
                            },
                            child: const Text("Press me"),
                          )),
                          const AllReferences(),
                          /***************/
                          /* UI elements */
                          /***************/
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Toolbar(),
                          ),
                        ]
                    ),
                  ),
                  const ReferenceSidebar(),
                ],
              ),
            ),
          );
        }
    );
  }
}


class _CameraProvider extends SingleChildStatefulWidget {
  const _CameraProvider({super.key, super.child});

  @override
  State<_CameraProvider> createState() => _CameraProviderState();
}

class _CameraProviderState extends SingleChildState<_CameraProvider> {
  late final MapCamera _camera;

  bool _initialized = false;

  void _onCameraInitialized() {
    _camera.addListener(_onCameraUpdate);
  }

  void _onCameraUpdate() {
    PageStorage.maybeOf(context)?.writeState(
        context,
        _camera.snapshot,
        identifier: const ValueKey('MapCameraProvider#snapshot')
    );
  }

  @override
  void initState() {
    super.initState();

    MapCameraSnapshot? snapshot = PageStorage.maybeOf(context)?.readState(
        context,
        identifier: const ValueKey('MapCameraProvider#snapshot')
    );
    if (snapshot != null) {
      _camera = MapCamera.fromSnapshot(snapshot);
      _initialized = true;
      _onCameraInitialized();
    }
  }

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
            size: Size(constraints.maxWidth - (_debugPadding??0)*2, constraints.maxHeight - (_debugPadding??0)*2)
          );
          _initialized = true;
          _onCameraInitialized();
        } else {
          _camera.size = Size(constraints.maxWidth - (_debugPadding??0)*2, constraints.maxHeight - (_debugPadding??0)*2);
        }

        return ChangeNotifierProvider.value(value: _camera, child: child);
      },
    );
  }
}


class _ToolSelectionProvider extends SingleChildStatefulWidget {
  const _ToolSelectionProvider({super.key, super.child});

  @override
  State<_ToolSelectionProvider> createState() => _ToolSelectionProviderState();
}

class _ToolSelectionProviderState extends SingleChildState<_ToolSelectionProvider> {
  late final ToolSelection _toolSelection;

  void _onToolSelectionInitialized() {
    _toolSelection.addListener(_onToolSelectionUpdate);
  }

  void _onToolSelectionUpdate() {
    PageStorage.maybeOf(context)?.writeState(
        context,
        _toolSelection.selectedTool,
        identifier: const ValueKey('ToolSelectionProvider#selectedTool')
    );
  }

  @override
  void initState() {
    super.initState();

    Tool? snapshot = PageStorage.maybeOf(context)?.readState(
        context,
        identifier: const ValueKey('ToolSelectionProvider#selectedTool')
    );
    if (snapshot != null) {
      _toolSelection = ToolSelection.initial(snapshot);
    } else {
      _toolSelection = ToolSelection();
    }
    _onToolSelectionInitialized();
  }

  @override
  void dispose() {
    super.dispose();
    _toolSelection.dispose();
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) =>
      ChangeNotifierProvider.value(value: _toolSelection, child: child);
}


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
