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

Future<void> moveImageToHistoricalStorage(Project project, Reference ref) async {
  String firstTwo = ref.uuid.substring(0, 2);
  Directory tmpStorageDir = await project.root
      .resolve('history_storage')
      .resolve('references')
      .resolve(firstTwo)
      .create(recursive: true);

  await ref.image.toFile().rename(tmpStorageDir.resolveFile(ref.uuid).path);
}

abstract class _ActivatableReferenceHistoryEntry extends HistoryEntry implements LogicallyDisposable<HistoryContext> {
  final String _uuid;
  Map<String, dynamic>? _actualData;

  _ActivatableReferenceHistoryEntry(this._uuid, this._actualData);

  Future<void> _deactivate(Project project) async {
    final ref = project.getReference(_uuid)!;
    logger.d("Deactivating Reference($ref)");
    _actualData = ref.toJson();

    await moveImageToHistoricalStorage(project, ref);

    project.references.remove(ref);

    await project.save(); // must save to prevent desync with image storage
  }

  Future<void> _activate(Project project, {int? index}) async {
    Reference ref = Reference.fromJson(project.loadingContext, _actualData!);
    logger.d("Activating Reference($ref)");

    // copy back image
    String firstTwo = ref.uuid.substring(0, 2);
    Directory tmpStorageDir = project.root
        .resolve('history_storage')
        .resolve('references')
        .resolve(firstTwo);

    await tmpStorageDir.resolveFile(ref.uuid).rename(ref.image.toFile().path);

    project.references.add(ref, index: index);

    if (await tmpStorageDir.list().isEmpty) {
      await tmpStorageDir.delete();
    }

    _actualData = null;

    await project.save(); // must save to prevent desync with image storage
  }

  @override
  Map<String, dynamic> toJson() {
    return _actualData != null ? {
      'uuid': _uuid,
      'actualData': _actualData,
    } : {
      'uuid': _uuid,
    };
  }

  @override
  String toString() => "${runtimeType.toString()}($_uuid)";

  @override
  void disposeLogical(HistoryContext context) {
    logger.d("Disposing $this");

    String firstTwo = _uuid.substring(0, 2);
    Directory tmpStorageDir = context.project.root
        .resolve('history_storage')
        .resolve('references')
        .resolve(firstTwo);

    tmpStorageDir.resolveFile(_uuid).deleteSync();

    if (tmpStorageDir.listSync().isEmpty) {
      tmpStorageDir.delete();
    }
  }
}

class AddReferenceHistoryEntry extends _ActivatableReferenceHistoryEntry {
  factory AddReferenceHistoryEntry(Reference reference) {
    return AddReferenceHistoryEntry._(reference.uuid, null);
  }

  AddReferenceHistoryEntry._(super._uuid, super._actualData);

  factory AddReferenceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AddReferenceHistoryEntry._(
      json['uuid'],
      json['actualData']
    );
  }

  @override
  Future<void> redo(Project project) async {
    await _activate(project);
  }

  @override
  Future<void> undo(Project project) async {
    await _deactivate(project);
  }

  @override
  HistoryEntryType get type => HistoryEntryType.addReference;

  @override
  void assertValidOnRedoStack() {
    super.assertValidOnRedoStack();
    assert(_actualData != null);
  }
}

class RemoveReferenceHistoryEntry extends _ActivatableReferenceHistoryEntry {
  final int _index;

  factory RemoveReferenceHistoryEntry(Reference reference, int index) {
    return RemoveReferenceHistoryEntry._(reference.uuid, reference.toJson(), index);
  }

  RemoveReferenceHistoryEntry._(super._uuid, super._actualData, this._index);

  factory RemoveReferenceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RemoveReferenceHistoryEntry._(
      json['uuid'],
      json['actualData'],
      json['index'] ?? 0
    );
  }

  @override
  Future<void> redo(Project project) async {
    await _deactivate(project);
  }

  @override
  Future<void> undo(Project project) async {
    await _activate(project, index: _index);
  }

  @override
  HistoryEntryType get type => HistoryEntryType.removeReference;

  @override
  void assertValidOnUndoStack() {
    super.assertValidOnUndoStack();
    assert(_actualData != null);
  }

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
    ..['index'] = _index;
  }
}

class ReorderReferenceHistoryEntry extends HistoryEntry {
  final String _uuid;
  final int _oldIndex;
  final int _newIndex;

  ReorderReferenceHistoryEntry(this._uuid, this._oldIndex, this._newIndex);

  factory ReorderReferenceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReorderReferenceHistoryEntry(
      json['uuid'],
      json['oldIndex'],
      json['newIndex']
    );
  }

  @override
  Future<void> undo(Project project) async {
    int frm = _newIndex;
    int to = _oldIndex;
    if (_oldIndex < _newIndex - 1) {
      frm--;
    } else if (_oldIndex > _newIndex + 1) {
      to++;
    }
    project.references.reorder(project.historyManager, frm, to, skipHistory: true, uuid: _uuid);
  }

  @override
  Future<void> redo(Project project) async {
    project.references.reorder(project.historyManager, _oldIndex, _newIndex, skipHistory: true, uuid: _uuid);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': _uuid,
      'oldIndex': _oldIndex,
      'newIndex': _newIndex,
    };
  }

  @override
  HistoryEntryType get type => HistoryEntryType.reorderReference;

  @override
  String toString() {
    return "ReorderReferenceHistoryEntry($_uuid, $_oldIndex -> $_newIndex)";
  }
}

class ModifyReferenceTitleHistoryEntry extends HistoryEntry {
  final String _uuid;
  final String _oldTitle;
  final String _newTitle;

  ModifyReferenceTitleHistoryEntry(this._uuid, this._oldTitle, this._newTitle);

  factory ModifyReferenceTitleHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ModifyReferenceTitleHistoryEntry(
      json['uuid'],
      json['oldTitle'],
      json['newTitle']
    );
  }

  @override
  Future<void> undo(Project project) async {
    final ref = project.getReference(_uuid)!;
    ref.setTitle(project.historyManager, _oldTitle, skipHistory: true);
  }

  @override
  Future<void> redo(Project project) async {
    final ref = project.getReference(_uuid)!;
    ref.setTitle(project.historyManager, _newTitle, skipHistory: true);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': _uuid,
      'oldTitle': _oldTitle,
      'newTitle': _newTitle,
    };
  }

  @override
  HistoryEntryType get type => HistoryEntryType.modifyReferenceTitle;

  @override
  String toString() {
    return "ModifyReferenceTitleHistoryEntry($_uuid, $_oldTitle -> $_newTitle)";
  }
}

class ModifyReferenceBlendModeHistoryEntry extends HistoryEntry {
  final String _uuid;
  final BlendMode _oldBlendMode;
  final BlendMode _newBlendMode;

  ModifyReferenceBlendModeHistoryEntry(this._uuid, this._oldBlendMode, this._newBlendMode);

  factory ModifyReferenceBlendModeHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ModifyReferenceBlendModeHistoryEntry(
      json['uuid'],
      BlendMode.values.where((e) => e.name == json['oldBlendMode']).firstOrNull ?? BlendMode.srcOver,
      BlendMode.values.where((e) => e.name == json['newBlendMode']).firstOrNull ?? BlendMode.srcOver,
    );
  }

  @override
  Future<void> undo(Project project) async {
    final ref = project.getReference(_uuid)!;
    ref.setBlendMode(project.historyManager, _oldBlendMode, skipHistory: true);
  }

  @override
  Future<void> redo(Project project) async {
    final ref = project.getReference(_uuid)!;
    ref.setBlendMode(project.historyManager, _newBlendMode, skipHistory: true);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': _uuid,
      'oldBlendMode': _oldBlendMode.name,
      'newBlendMode': _newBlendMode.name,
    };
  }

  @override
  HistoryEntryType get type => HistoryEntryType.modifyReferenceBlendMode;

  @override
  String toString() {
    return "ModifyReferenceBlendModeHistoryEntry($_uuid, $_oldBlendMode -> $_newBlendMode)";
  }
}
