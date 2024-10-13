import 'dart:ui';

import 'package:flutter/material.dart';

extension ColorManipulation on Color {
  Color darken([double factor = 0.1]) {
    assert(factor >= 0 && factor <= 1);

    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - factor).clamp(0.0, 1.0));

    return hslDark.toColor();
  }

  Color lighten([double factor = 0.1]) {
    assert(factor >= 0 && factor <= 1);

    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + factor).clamp(0.0, 1.0));

    return hslLight.toColor();
  }
}