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

import '../../logger.dart';

class SimpleEditableText extends StatefulWidget {
  final String initialText;
  final TextStyle? style;
  final bool dense;
  final void Function(String) onChanged;
  /// Setup external listener that will invoke [callback] when the widget is about to be disposed.
  final void Function(void Function() callback)? addPreDisposeCallback;
  /// Remove external listener that was setup with [addPreDisposeCallback].
  final void Function(void Function() callback)? removePreDisposeCallback;

  const SimpleEditableText(this.initialText,
      {super.key,
      this.style,
      this.dense = false,
      required this.onChanged,
      this.addPreDisposeCallback,
      this.removePreDisposeCallback});

  @override
  State<SimpleEditableText> createState() => _SimpleEditableTextState();
}

class _SimpleEditableTextState extends State<SimpleEditableText> {

  final FocusNode _focusNode = FocusNode(debugLabel: "SimpleEditableText");
  late String _text;

  @override
  void initState() {
    super.initState();

    _text = widget.initialText;
    widget.addPreDisposeCallback?.call(_submit);
  }

  void _submit() {
    widget.onChanged(_text);
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.removePreDisposeCallback?.call(_submit);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: _focusNode,
      controller: TextEditingController(text: _text),
      style: (widget.style ?? const TextStyle()).copyWith(height: 1),
      onSubmitted: (value) {
        _text = value;
        _submit();
      },
      onChanged: (value) => _text = value,
      maxLines: 1,
      onTapOutside: (_) => _submit,
      decoration: widget.dense ? const InputDecoration(
        suffixIcon: SizedBox(width: 0, height: 20),
        suffixIconConstraints: BoxConstraints.tightFor(height: 20),
        isDense: true,
      ) : null,
      textAlignVertical: TextAlignVertical.center,
    );
  }
}
