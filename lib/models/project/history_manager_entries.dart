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

part of 'history_manager.dart';

class ExampleHistoryEntry extends HistoryEntry {
  final String exampleField;

  ExampleHistoryEntry(this.exampleField);

  factory ExampleHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ExampleHistoryEntry(json['exampleField']);
  }

  @override
  void undo(Project project) {
    logger.d('Undoing example history entry $exampleField');
  }

  @override
  void redo(Project project) {
    logger.d('Redoing example history entry $exampleField');
  }

  @override
  HistoryEntryType get type => HistoryEntryType.example;

  @override
  Map<String, dynamic> toJson() {
    return {
      'exampleField': exampleField,
    };
  }
}
