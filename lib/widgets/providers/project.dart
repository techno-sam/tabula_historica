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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../util/async_timer.dart';
import '../../models/project/project.dart';

class ProjectProvider extends SingleChildStatefulWidget {

  final Directory rootDir;

  const ProjectProvider({super.key, required this.rootDir});

  @override
  State<ProjectProvider> createState() => _ProjectProviderState();
}

class _ProjectProviderState extends SingleChildState<ProjectProvider> {

  late Project? _project;
  late AsyncTimer _saveTimer;

  @override
  void initState() {
    super.initState();
    _project = Project.load(widget.rootDir);
    _saveTimer = AsyncTimer(const Duration(seconds: 5), (_) async {
      if (_project!.needsSave) {
        await _project!.save();
      }
    });
  }

  @override
  void dispose() {
    _saveTimer.cancel();
    if (_project!.needsSave) {
      _project!.save();
    }
    _project!.dispose();
    _project = null;
    super.dispose();
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return MultiProvider(
      providers: [
        Provider.value(value: _project!),
        ChangeNotifierProvider.value(value: _project!.historyManager),
        ChangeNotifierProvider.value(value: _project!.references),
        ChangeNotifierProvider.value(value: _project!.structures),
      ], child: child,
    );
  }
}
