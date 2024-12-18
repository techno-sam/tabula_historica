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

class AddReferenceHistoryEntry extends HistoryEntry {
  final String _uuid;
  Map<String, dynamic>? _actualData;

  factory AddReferenceHistoryEntry(Reference reference) {
    return AddReferenceHistoryEntry._(reference.uuid, reference.toJson());
  }

  AddReferenceHistoryEntry._(this._uuid, this._actualData);

  factory AddReferenceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AddReferenceHistoryEntry(json['exampleField']);
  }

  @override
  Future<void> undo(Project project) async {
    final ref = project.getReference(_uuid)!;
    logger.d('Undoing AddReference($ref)');
    _actualData = ref.toJson();
    // copy over image
    String firstTwo = ref.uuid.substring(0, 2);
    Directory tmpStorageDir = await project.root
        .resolve("history_storage")
        .resolve("references")
        .resolve(firstTwo)
        .create(recursive: true);

    await ref.image.toFile().rename(tmpStorageDir.resolveFile(ref.uuid).path);

    await project.removeReference(ref);
  }

  @override
  Future<void> redo(Project project) async {
    Reference ref = Reference.fromJson(project.loadingContext, _actualData!);
    logger.d('Redoing AddReference($ref)');

    // copy back image
    String firstTwo = ref.uuid.substring(0, 2);
    Directory tmpStorageDir = project.root
        .resolve("history_storage")
        .resolve("references")
        .resolve(firstTwo);

    await tmpStorageDir.resolveFile(ref.uuid).rename(ref.image.toFile().path);

    project.references.add(ref);

    if (await tmpStorageDir.list().isEmpty) {
      await tmpStorageDir.delete();
    }
  }

  @override
  void assertValidOnRedoStack() {
    super.assertValidOnRedoStack();
    assert(_actualData != null);
  }

  @override
  HistoryEntryType get type => HistoryEntryType.addReference;

  @override
  Map<String, dynamic> toJson() {
    return _actualData != null ? {
      "uuid": _uuid,
      "actualData": _actualData,
    } : {
      "uuid": _uuid,
    };
  }

  @override
  String toString() => 'AddReferenceHistoryEntry($_uuid)';
}
