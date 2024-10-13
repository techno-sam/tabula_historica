import 'package:flutter/material.dart';
import 'package:track_map/widgets/map/multi_lod.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: const Text('Demo Map'),
      ),
      body: const MultiLODMap(),
    );
  }
}
