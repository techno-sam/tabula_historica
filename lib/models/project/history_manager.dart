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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'foundation/needs_save.dart';

class HistoryManager extends ChangeNotifier with NeedsSave {

  HistoryManager();

  factory HistoryManager.fromJson(Map<String, dynamic> json) {
    return HistoryManager();
  }

  Map<String, dynamic> toJson() {
    return {};
  }

  static HistoryManager of(BuildContext context) {
    return Provider.of(context, listen: false);
  }
}