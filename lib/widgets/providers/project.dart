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
import 'package:tabula_historica/extensions/color_manipulation.dart';
import 'package:tabula_historica/util/splash_control.dart';

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

class AssetBasedProjectProvider extends SingleChildStatefulWidget {
  const AssetBasedProjectProvider({super.key});

  @override
  State<AssetBasedProjectProvider> createState() => _AssetBasedProjectProviderState();
}

class _AssetBasedProjectProviderState extends SingleChildState<AssetBasedProjectProvider> {
  late Future<Project> _project;
  Project? _projectInstance;

  void _doLoad() {
    if (_projectInstance != null) {
      _projectInstance!.dispose();
    }
    _project = Project.loadFromAssets();
  }

  @override
  void initState() {
    super.initState();
    _doLoad();
  }

  @override
  void dispose() {
    if (_projectInstance != null) {
      _projectInstance!.dispose();
    } else {
      _project.then((project) => project.dispose());
    }
    _projectInstance = null;
    super.dispose();
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    if (_projectInstance != null) {
      return MultiProvider(
        providers: [
          Provider.value(value: _projectInstance!),
          ChangeNotifierProvider.value(value: _projectInstance!.structures),
        ], child: child,
      );
    } else {
      return FutureBuilder(
        future: _project,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            getSplashControl().sendSplashClearEvent();
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'The Gauls got to us! Failed to load project.',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${snapshot.error}",
                      style: TextStyle(color: Colors.red.darken(0.25)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _doLoad();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            _projectInstance = snapshot.data as Project;
            return MultiProvider(
              providers: [
                Provider.value(value: _projectInstance!),
                ChangeNotifierProvider.value(value: _projectInstance!.structures),
              ], child: child,
            );
          }
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Building Rome in a day...'),
                CircularProgressIndicator(),
              ],
            )
          );
        }
      );
    }
  }
}
