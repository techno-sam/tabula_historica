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

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';

class TransformPlayground extends StatelessWidget {
  const TransformPlayground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 20,
          top: 40,
          child: Container(
            color: Colors.cyan.withValues(alpha: 0.2),
            child: const SizedBox(
              width: 520,
              height: 420,
              child: Center(
                child: TransformableImage(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TransformableImage extends StatefulWidget {

  final bool skipStack;

  const TransformableImage({super.key, this.skipStack = false});

  @override
  State<TransformableImage> createState() => _TransformableImageState();
}

class _TransformableImageState extends State<TransformableImage> {

  Rect _rect = const Rect.fromLTWH(0, 0, 800/2, 450/2);

  late final int _random;

  @override
  void initState() {
    super.initState();

    _random = Random().nextInt(100);
  }

  @override
  Widget build(BuildContext context) {

    final supportedDragDevices = PointerDeviceKind.values
        .toSet()
        .difference({PointerDeviceKind.trackpad});

    final transformableBox = TransformableBox(
          rect: _rect,
          flip: Flip.none,
          allowContentFlipping: false,
          allowFlippingWhileResizing: false,
          draggable: true,
          resizable: true,
          //clampingRect: const Rect.fromLTWH(0, 0, 520, 420),
          constraints: const BoxConstraints(
            minWidth: 80,
            minHeight: 45,
          ),
          supportedDragDevices: supportedDragDevices,
          supportedResizeDevices: supportedDragDevices,

          onChanged: (result, details) {
            setState(() {
              _rect = result.rect;
            });
          },

          contentBuilder: (context, rect, flip) => Image.network(
            "https://picsum.photos/800/450?random=$_random",
            width: rect.width,
            height: rect.height,
            fit: BoxFit.fill,
          ),
        );

    if (widget.skipStack) {
      return transformableBox;
    }

    return Stack(
      children: [
        transformableBox,
      ],
    );
  }
}