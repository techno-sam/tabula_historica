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

import 'package:flutter/gestures.dart';

extension ButtonTypes on PointerEvent {
  bool get hasPrimaryButton => buttons & kPrimaryMouseButton != 0;
  bool get hasSecondaryButton => buttons & kSecondaryMouseButton != 0;
  bool get hasMiddleButton => buttons & kMiddleMouseButton != 0;

  bool matches({bool? primary, bool? secondary, bool? middle}) {
    if (primary != null && primary != hasPrimaryButton) {
      return false;
    }
    if (secondary != null && secondary != hasSecondaryButton) {
      return false;
    }
    if (middle != null && middle != hasMiddleButton) {
      return false;
    }
    return true;
  }
}
