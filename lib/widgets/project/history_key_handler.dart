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
import 'package:provider/single_child_widget.dart';
import 'package:tabula_historica/logger.dart';

import '../../models/project/history_manager.dart';
import '../../models/project/project.dart';
import '../../util/partial_future.dart';
import '../providers/keyboard_event.dart';

class HistoryKeyHandler extends SingleChildStatefulWidget {
  const HistoryKeyHandler({super.key});

  @override
  State<HistoryKeyHandler> createState() => _HistoryKeyHandlerState();
}

class _HistoryKeyHandlerState extends SingleChildState<HistoryKeyHandler> {

  KeyboardEventRegistrar? _registrar;

  PartialFuture<KeyEventResult, void> _onUndo(bool inProgress) {
    if (inProgress) return PartialFuture.value(KeyEventResult.ignored);

    return context.read<HistoryManager>().undo(context.read<Project>())
      .mapValue((handled) => handled ? KeyEventResult.handled : KeyEventResult.ignored);
  }

  PartialFuture<KeyEventResult, void> _onRedo(bool inProgress) {
    if (inProgress) return PartialFuture.value(KeyEventResult.ignored);

    return context.read<HistoryManager>().redo(context.read<Project>())
        .mapValue((handled) => handled ? KeyEventResult.handled : KeyEventResult.ignored);
  }

  PartialFuture<KeyEventResult, void> _onDebug(bool inProgress) {
    logger.i(context.read<HistoryManager>().debugInfo());
    return PartialFuture.value(KeyEventResult.handled);
  }

  void _register() {
    _registrar!.register(KeyboardEvent.undo, _onUndo);
    _registrar!.register(KeyboardEvent.redo, _onRedo);
    _registrar!.register(KeyboardEvent.debug, _onDebug);
  }

  void _unregister() {
    _registrar!.unregister(KeyboardEvent.undo, _onUndo);
    _registrar!.unregister(KeyboardEvent.redo, _onRedo);
    _registrar!.unregister(KeyboardEvent.debug, _onDebug);
  }

  @override
  void initState() {
    super.initState();

    _registrar = context.read<KeyboardEventRegistrar>();
    _register();
  }

  @override
  void didChangeDependencies() {
    final registrar = context.read<KeyboardEventRegistrar>();
    if (registrar != _registrar) {
      _unregister();
      _registrar = registrar;
      _register();
    }

    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _unregister();
    _registrar = null;

    super.dispose();
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return child ?? const SizedBox();
  }
}