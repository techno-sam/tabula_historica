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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../util/partial_future.dart';

enum KeyboardEvent {
  undo,
  redo,
  debug
}

typedef KeyEventHandler = PartialFuture<KeyEventResult, void> Function(bool alreadyInProgress);

class _HandlerEntry {
  final KeyEventHandler _handler;
  final Map<UniqueKey, Future<void>> _futures = {};

  bool get _isInProgress => _futures.isNotEmpty;

  _HandlerEntry(this._handler);

  @pragma('vm:prefer-inline')
  bool holds(KeyEventHandler handler) => _handler == handler;

  PartialFuture<KeyEventResult, void> call() {
    final result = _handler(_isInProgress);
    _addFuture(result.future);
    return result;
  }

  void _addFuture(Future<void> future) {
    final key = UniqueKey();
    _futures[key] = future.then((_) {
      _futures.remove(key);
    });
  }
}

class KeyboardEventRegistrar {
  final Map<KeyboardEvent, List<_HandlerEntry>> _eventHandlers = {};

  /// A handler can return true to indicate that the event was handled and should not be propagated further.
  /// The last-added handler for an event will be the first to be called.
  void register(KeyboardEvent event, KeyEventHandler handler) {
    _eventHandlers[event] ??= [];
    _eventHandlers[event]!.insert(0, _HandlerEntry(handler));
  }

  void unregister(KeyboardEvent event, KeyEventHandler handler) {
    _eventHandlers[event]?.removeWhere((entry) => entry.holds(handler));
  }

  PartialFuture<KeyEventResult, void> handleEvent(KeyboardEvent event) {
    final handlers = _eventHandlers[event] ?? [];
    final List<Future<void>> futures = [];

    for (final handler in handlers) {
      final result = handler();
      futures.add(result.future);
      if (result.value != KeyEventResult.ignored) {
        return PartialFuture(value: result.value, future: Future.wait(futures));
      }
    }
    return PartialFuture(value: KeyEventResult.ignored, future: Future.wait(futures));
  }

  void dispose() {
    _eventHandlers.clear();
  }
}

class KeyboardEventProvider extends SingleChildStatefulWidget {
  const KeyboardEventProvider({super.key, super.child});

  @override
  State<KeyboardEventProvider> createState() => _KeyboardEventProviderState();
}

class _KeyboardEventProviderState extends SingleChildState<KeyboardEventProvider> {
  late final FocusNode _focusNode;
  late final KeyboardEventRegistrar _registrar;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _registrar = KeyboardEventRegistrar();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _registrar.dispose();
    super.dispose();
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: false,
      child: Provider.value(
        value: _registrar,
        child: child ?? const SizedBox(),
      ),
      onKeyEvent: (_, final KeyEvent event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.keyZ && HardwareKeyboard.instance.isControlPressed) {
          return _registrar.handleEvent(KeyboardEvent.undo).value;
        } else if (event.logicalKey == LogicalKeyboardKey.keyY && HardwareKeyboard.instance.isControlPressed) {
          return _registrar.handleEvent(KeyboardEvent.redo).value;
        } else if (event.logicalKey == LogicalKeyboardKey.keyD && HardwareKeyboard.instance.isControlPressed) {
          return _registrar.handleEvent(KeyboardEvent.debug).value;
        }

        return KeyEventResult.ignored;
      },
    );
  }
}