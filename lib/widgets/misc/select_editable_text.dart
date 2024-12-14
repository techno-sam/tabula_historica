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

class SelectEditableText extends StatefulWidget {
  final String initialText;
  final TextStyle? style;

  const SelectEditableText(this.initialText, {super.key, this.style});

  @override
  State<SelectEditableText> createState() => _SelectEditableTextState();
}

class _SelectEditableTextState extends State<SelectEditableText> {

  final FocusNode _focusNode = FocusNode();
  bool _editing = false;
  late String _text;

  @override
  void initState() {
    super.initState();

    _text = widget.initialText;
  }

  void _startEditing() {
    setState(() {
      _editing = true;
    });
  }

  void _finishEditing() {
    setState(() {
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Flexible(
        child: Container(
          color: Colors.red.withOpacity(0.1),
          child: Row(
            children: [
              IconButton(
                onPressed: _finishEditing,
                icon: const Icon(Icons.check, size: 18),
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              ),
              Flexible(
                child: TextField(
                  focusNode: _focusNode,
                  controller: TextEditingController(text: _text),
                  style: (widget.style ?? const TextStyle()).copyWith(height: 1),
                  decoration: const InputDecoration.collapsed(
                    hintText: "",
                    border: UnderlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    _text = value;
                    _finishEditing();
                  },
                  maxLines: 1,
                  onTapOutside: (_) => _finishEditing,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Row(
        children: [
          IconButton(
            onPressed: _startEditing,
            icon: const Icon(Icons.edit, size: 18),
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          ),
          Text(_text, style: widget.style, maxLines: 1,),
        ],
      );
    }
  }
}