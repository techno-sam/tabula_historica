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

/*==========================*/
/* Abstract History Entries */
/*==========================*/

abstract class _ReorderHistoryEntry<T extends Object> extends HistoryEntry {
  final String _uuid;
  final int _oldIndex;
  final int _newIndex;

  _ReorderHistoryEntry(this._uuid, this._oldIndex, this._newIndex);

  ReorderableListModel<T> _getList(Project project);

  @override
  Future<void> undo(Project project) async {
    int frm = _newIndex;
    int to = _oldIndex;
    if (_oldIndex < _newIndex - 1) {
      frm--;
    } else if (_oldIndex > _newIndex + 1) {
      to++;
    }
    _getList(project).reorder(project.historyManager, frm, to, skipHistory: true, uuid: _uuid);
  }

  @override
  Future<void> redo(Project project) async {
    _getList(project).reorder(project.historyManager, _oldIndex, _newIndex, skipHistory: true, uuid: _uuid);
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
  String toString() {
    return "${runtimeType.toString()}($_uuid, $_oldIndex -> $_newIndex)";
  }
}

/*===========================*/
/* Reference History Entries */
/*===========================*/

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

class ReorderReferenceHistoryEntry extends _ReorderHistoryEntry<Reference> {
  ReorderReferenceHistoryEntry(super._uuid, super._oldIndex, super._newIndex);

  factory ReorderReferenceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReorderReferenceHistoryEntry(
      json['uuid'],
      json['oldIndex'],
      json['newIndex']
    );
  }

  @override
  ReorderableListModel<Reference> _getList(Project project) => project.references;

  @override
  HistoryEntryType get type => HistoryEntryType.reorderReference;
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

class ModifyReferenceTransformHistoryEntry extends HistoryEntry {
  final String _uuid;
  final Transform2D _oldTransform;
  final Transform2D _newTransform;

  ModifyReferenceTransformHistoryEntry._(this._uuid, this._oldTransform, this._newTransform);

  ModifyReferenceTransformHistoryEntry(this._uuid, Transform2D oldTransform, Transform2D newTransform):
        _oldTransform = oldTransform.clone(), _newTransform = newTransform.clone();

  factory ModifyReferenceTransformHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ModifyReferenceTransformHistoryEntry._(
      json['uuid'],
      Transform2D.fromJson(json['oldTransform']),
      Transform2D.fromJson(json['newTransform'])
    );
  }

  @override
  Future<void> undo(Project project) async {
    final ref = project.getReference(_uuid)!;
    ref.updateTransformIntermediate((t) => t.copyFrom(_oldTransform), discardStart: true);
  }

  @override
  Future<void> redo(Project project) async {
    final ref = project.getReference(_uuid)!;
    ref.updateTransformIntermediate((t) => t.copyFrom(_newTransform), discardStart: true);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': _uuid,
      'oldTransform': _oldTransform.toJson(),
      'newTransform': _newTransform.toJson(),
    };
  }

  @override
  HistoryEntryType get type => HistoryEntryType.modifyReferenceTransform;

  @override
  String toString() {
    List<String> changes = [];
    const double epsilon = 0.0001;
    if (_oldTransform.translationX.differs(_newTransform.translationX, epsilon)) {
      changes.add("translationX: ${_oldTransform.translationX.toStringAsFixed(2)} -> ${_newTransform.translationX.toStringAsFixed(2)}");
    }
    if (_oldTransform.translationY.differs(_newTransform.translationY, epsilon)) {
      changes.add("translationY: ${_oldTransform.translationY.toStringAsFixed(2)} -> ${_newTransform.translationY.toStringAsFixed(2)}");
    }
    if (_oldTransform.scaleX.differs(_newTransform.scaleX, epsilon)) {
      changes.add("scaleX: ${_oldTransform.scaleX.toStringAsFixed(2)} -> ${_newTransform.scaleX.toStringAsFixed(2)}");
    }
    if (_oldTransform.scaleY.differs(_newTransform.scaleY, epsilon)) {
      changes.add("scaleY: ${_oldTransform.scaleY.toStringAsFixed(2)} -> ${_newTransform.scaleY.toStringAsFixed(2)}");
    }
    if (_oldTransform.rotation.differs(_newTransform.rotation, epsilon)) {
      changes.add("rotation: ${_oldTransform.rotation.toStringAsFixed(2)} -> ${_newTransform.rotation.toStringAsFixed(2)}");
    }
    return "ModifyReferenceTransformHistoryEntry($_uuid, ${changes.join(", ")})";
  }
}

class ModifyReferenceOpacityHistoryEntry extends HistoryEntry {
  final String _uuid;
  final double _oldOpacity;
  final double _newOpacity;

  ModifyReferenceOpacityHistoryEntry(this._uuid, this._oldOpacity, this._newOpacity);

  factory ModifyReferenceOpacityHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ModifyReferenceOpacityHistoryEntry(
      json['uuid'],
      (json['oldOpacity'] as num).toDouble(),
      (json['newOpacity'] as num).toDouble()
    );
  }

  @override
  Future<void> undo(Project project) async {
    final ref = project.getReference(_uuid)!;
    ref.updateOpacityIntermediate(_oldOpacity, discardStart: true);
  }

  @override
  Future<void> redo(Project project) async {
    final ref = project.getReference(_uuid)!;
    ref.updateOpacityIntermediate(_newOpacity, discardStart: true);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': _uuid,
      'oldOpacity': _oldOpacity,
      'newOpacity': _newOpacity,
    };
  }

  @override
  HistoryEntryType get type => HistoryEntryType.modifyReferenceOpacity;

  @override
  String toString() {
    return "ModifyReferenceOpacityHistoryEntry($_uuid, $_oldOpacity -> $_newOpacity)";
  }
}

/*===========================*/
/* Structure History Entries */
/*===========================*/

abstract class _ActivatableStructureHistoryEntry extends HistoryEntry {
  final String _uuid;
  Map<String, dynamic>? _actualData;

  _ActivatableStructureHistoryEntry(this._uuid, this._actualData);

  Future<void> _deactivate(Project project) async {
    final structure = project.getStructure(_uuid)!;
    logger.d("Deactivating Structure($structure)");
    _actualData = structure.toJson();

    project.structures.remove(structure);
  }

  Future<void> _activate(Project project, {int? index}) async {
    Structure structure = Structure.fromJson(_actualData!);
    logger.d("Activating Structure($structure)");
    project.structures.add(structure, index: index);
    _actualData = null;
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
}

class AddStructureHistoryEntry extends _ActivatableStructureHistoryEntry {
  factory AddStructureHistoryEntry(Structure structure) {
    return AddStructureHistoryEntry._(structure.uuid, null);
  }

  AddStructureHistoryEntry._(super._uuid, super._actualData);

  factory AddStructureHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AddStructureHistoryEntry._(
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
  HistoryEntryType get type => HistoryEntryType.addStructure;

  @override
  void assertValidOnRedoStack() {
    super.assertValidOnRedoStack();
    assert(_actualData != null);
  }
}

class RemoveStructureHistoryEntry extends _ActivatableStructureHistoryEntry {
  final int _index;

  factory RemoveStructureHistoryEntry(Structure structure, int index) {
    return RemoveStructureHistoryEntry._(structure.uuid, structure.toJson(), index);
  }

  RemoveStructureHistoryEntry._(super._uuid, super._actualData, this._index);

  factory RemoveStructureHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RemoveStructureHistoryEntry._(
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
  HistoryEntryType get type => HistoryEntryType.removeStructure;

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

class ReorderStructureHistoryEntry extends _ReorderHistoryEntry<Structure> {
  ReorderStructureHistoryEntry(super._uuid, super._oldIndex, super._newIndex);

  factory ReorderStructureHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReorderStructureHistoryEntry(
        json['uuid'],
        json['oldIndex'],
        json['newIndex']
    );
  }

  @override
  ReorderableListModel<Structure> _getList(Project project) => project.structures;

  @override
  HistoryEntryType get type => HistoryEntryType.reorderStructure;
}

class ModifyStructureTitleHistoryEntry extends HistoryEntry {
  final String _uuid;
  final String _oldTitle;
  final String _newTitle;

  ModifyStructureTitleHistoryEntry(this._uuid, this._oldTitle, this._newTitle);

  factory ModifyStructureTitleHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ModifyStructureTitleHistoryEntry(
      json['uuid'],
      json['oldTitle'],
      json['newTitle']
    );
  }

  @override
  Future<void> undo(Project project) async {
    final structure = project.getStructure(_uuid)!;
    structure.setTitle(project.historyManager, _oldTitle, skipHistory: true);
  }

  @override
  Future<void> redo(Project project) async {
    final structure = project.getStructure(_uuid)!;
    structure.setTitle(project.historyManager, _newTitle, skipHistory: true);
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
  HistoryEntryType get type => HistoryEntryType.modifyStructureTitle;

  @override
  String toString() {
    return "ModifyStructureTitleHistoryEntry($_uuid, $_oldTitle -> $_newTitle)";
  }
}

class ModifyStructureDescriptionHistoryEntry extends HistoryEntry {
  final String _uuid;
  final String? _oldDescription;
  final String? _newDescription;

  ModifyStructureDescriptionHistoryEntry(this._uuid, this._oldDescription, this._newDescription);

  factory ModifyStructureDescriptionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ModifyStructureDescriptionHistoryEntry(
        json['uuid'],
        json['oldDescription'],
        json['newDescription']
    );
  }

  @override
  Future<void> undo(Project project) async {
    final structure = project.getStructure(_uuid)!;
    structure.setDescription(project.historyManager, _oldDescription, skipHistory: true);
  }

  @override
  Future<void> redo(Project project) async {
    final structure = project.getStructure(_uuid)!;
    structure.setDescription(project.historyManager, _newDescription, skipHistory: true);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': _uuid,
      'oldDescription': _oldDescription,
      'newDescription': _newDescription,
    };
  }

  @override
  HistoryEntryType get type => HistoryEntryType.modifyStructureDescription;

  @override
  String toString() {
    return "ModifyStructureDescriptionHistoryEntry($_uuid, $_oldDescription -> $_newDescription)";
  }
}

class ModifyStructurePenHistoryEntry extends HistoryEntry {
  final String _uuid;
  final Pen _oldPen;
  final Pen _newPen;

  ModifyStructurePenHistoryEntry(this._uuid, this._oldPen, this._newPen);

  factory ModifyStructurePenHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ModifyStructurePenHistoryEntry(
        json['uuid'],
        Pen.fromJson(json['oldPen']),
        Pen.fromJson(json['newPen'])
    );
  }

  @override
  Future<void> undo(Project project) async {
    final structure = project.getStructure(_uuid)!;
    structure.setPen(project.historyManager, _oldPen, skipHistory: true);
  }

  @override
  Future<void> redo(Project project) async {
    final structure = project.getStructure(_uuid)!;
    structure.setPen(project.historyManager, _newPen, skipHistory: true);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': _uuid,
      'oldPen': _oldPen.toJson(),
      'newPen': _newPen.toJson(),
    };
  }

  @override
  HistoryEntryType get type => HistoryEntryType.modifyStructurePen;

  @override
  String toString() {
    return "ModifyStructurePenHistoryEntry($_uuid, $_oldPen -> $_newPen)";
  }
}