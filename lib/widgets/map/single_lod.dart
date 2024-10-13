import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:track_map/backend/backend.dart' as backend;

class SingleLODMap extends StatelessWidget {
  final int lod;

  const SingleLODMap({super.key, required this.lod});

  @override
  Widget build(BuildContext context) {
    final client = context.watch<backend.Connection>();

    final lod = client.getLODs().then((v) => v[this.lod]);

    return Container(
      color: Colors.blue,
      child: FutureBuilder(
        future: lod,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }

          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }

          final lod = snapshot.data as backend.LodEntry;

          return Center(
            child: _SingleLODMap(lodId: this.lod, lod: lod),
          );
        },
      )
    );
  }
}

class _SingleLODMap extends StatelessWidget {
  final int lodId;
  final backend.LodEntry lod;

  const _SingleLODMap({super.key, required this.lodId, required this.lod});

  @override
  Widget build(BuildContext context) {
    const int tileSize = 512;

    double tileScale = 1 / 32;
    Point<double> offset = const Point(200, 200);

    int delay = 0;

    return Container(
      color: Colors.red,
      child: Container(
        color: Colors.blueGrey,
        child: Stack(
          children: [
            for (int x = lod.minX; x <= lod.maxX; x++)
              for (int z = lod.minZ; z <= lod.maxZ; z++)
                Positioned(
                  left: x * tileSize * tileScale + offset.x,
                  top: z * tileSize * tileScale + offset.y,
                  width: tileSize * tileScale,
                  height: tileSize * tileScale,
                  child: Container(
                    color: Colors.black,
                    child: FutureBuilder(
                      future: Future.delayed(Duration(milliseconds: (delay++) * 40)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.blue));
                        }
                        return Image.network(
                          'http://localhost:80/map_data/$lodId/x$x/z$z.png',
                          width: tileSize.toDouble(),
                          height: tileSize.toDouble(),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                          cacheWidth: tileSize,
                          cacheHeight: tileSize,
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
                            }
                          },
                        );
                      }
                    ),
                  ),
                ),
          ],
        ),
      )
    );
  }
}