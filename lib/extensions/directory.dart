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

import 'dart:io';

extension ChildDirectory on Directory {
  Directory resolve(String reference) => Directory.fromUri(uri.resolve(reference));
  Directory resolveUri(Uri reference) => Directory.fromUri(uri.resolveUri(reference));

  File resolveFile(String reference) => File.fromUri(uri.resolve(reference));
  File resolveFileUri(Uri reference) => File.fromUri(uri.resolveUri(reference));
}