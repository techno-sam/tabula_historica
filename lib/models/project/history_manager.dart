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
import 'package:ring_stack/ring_stack.dart';

import '../../logger.dart';
import '../../util/partial_future.dart';
import 'project.dart';
import 'foundation/needs_save.dart';

part 'history_manager_entries.dart';

const int maxHistorySize = 1000;
const int maxRedoSize = 100;

enum HistoryEntryType {
  example(ExampleHistoryEntry.fromJson),
  ;

  final HistoryEntry Function(Map<String, dynamic> json) _fromJson;

  const HistoryEntryType(this._fromJson);

  static HistoryEntry fromJson(Map<String, dynamic> json) {
    final type = HistoryEntryType.values.firstWhere((type) => type.toString() == json['type']);
    return type._fromJson(json);
  }
  
  static Map<String, dynamic> toJson(HistoryEntry entry) {
    final main = entry.toJson();
    assert(!main.containsKey('type'));
    return {
      'type': entry.type.toString(),
      ...main,
    };
  }
}

abstract class HistoryEntry {
  Future<void> undo(Project project);
  Future<void> redo(Project project);

  void assertValidOnUndoStack() {}
  void assertValidOnRedoStack() {}

  HistoryEntryType get type;

  Map<String, dynamic> toJson();
}

class HistoryManager extends ChangeNotifier with NeedsSave {

  final RingStack<HistoryEntry> _undoStack = RingStack(maxHistorySize);
  final RingStack<HistoryEntry> _redoStack = RingStack(maxRedoSize);

  HistoryManager({Iterable<HistoryEntry>? undoEntries, Iterable<HistoryEntry>? redoEntries}) {
    if (undoEntries != null) {
      for (final entry in undoEntries) {
        _undoStack.push(entry);
      }
    }

    if (redoEntries != null) {
      for (final entry in redoEntries) {
        _redoStack.push(entry);
      }
    }

    // Wrapped in an assert to avoid the overhead in production
    assert(() {
      for (final entry in _undoStack) {
        entry.assertValidOnUndoStack();
      }
      for (final entry in _redoStack) {
        entry.assertValidOnRedoStack();
      }
      return true;
    }());
  }

  factory HistoryManager.fromJson(Map<String, dynamic> json) {
    final undoEntries = <HistoryEntry>[];
    final redoEntries = <HistoryEntry>[];

    for (final entry in json['undoEntries']) {
      undoEntries.add(HistoryEntryType.fromJson(entry));
    }
    for (final entry in json['redoEntries']) {
      redoEntries.add(HistoryEntryType.fromJson(entry));
    }

    return HistoryManager(
      undoEntries: undoEntries,
      redoEntries: redoEntries,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'undoEntries': _undoStack.toList().map(HistoryEntryType.toJson).toList(),
      'redoEntries': _redoStack.toList().map(HistoryEntryType.toJson).toList(),
    };
  }

  PartialFuture<bool, void> undo(Project project) {
    if (_undoStack.isNotEmpty) {
      return PartialFuture.fromComputation(() async {
        final entry = _undoStack.pop();
        final future = entry.undo(project);
        _redoStack.push(entry);
        await future;
        notifyListeners();
      }, true);
    }
    return PartialFuture.value(false);
  }

  PartialFuture<bool, void> redo(Project project) {
    if (_redoStack.isNotEmpty) {
      return PartialFuture.fromComputation(() async {
        final entry = _redoStack.pop();
        final future = entry.redo(project);
        _undoStack.push(entry);
        await future;
        notifyListeners();
      }, true);
    }
    return PartialFuture.value(false);
  }

  void record(HistoryEntry entry) {
    _redoStack.clear(logicalDispose: true);
    _undoStack.push(entry);
    notifyListeners();
  }

  @override
  void dispose() {
    _undoStack.clear();
    super.dispose();
  }

  String debugInfo() {
    String out = "History State:\n";
    if (_redoStack.isNotEmpty) {
      for (final entry in _redoStack.reversed) {
        out += "\t$entry\n";
      }
      out += "-" * 20 + "\n";
      out += "^ Redo Stack\n";
    }
    if (_undoStack.isNotEmpty) {
      out += "v Undo Stack\n";
      out += "-" * 20 + "\n";
      for (final entry in _undoStack) {
        out += "\t$entry\n";
      }
    }
    return out;
  }

  static HistoryManager of(BuildContext context, {bool listen = false}) {
    return Provider.of(context, listen: listen);
  }
}
