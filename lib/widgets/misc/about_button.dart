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
import 'package:tabula_historica/widgets/misc/about_popup.dart';

class AboutButton extends StatelessWidget {
  const AboutButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SizedBox(
        width: 100,
        child: OutlinedButton(
          onPressed: () => showAboutPopup(context),
          style: OutlinedButton.styleFrom(
            elevation: 0,
            backgroundColor: theme.colorScheme.surfaceContainerLowest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4.0)),
              side: BorderSide(color: Colors.grey),
            ),
          ),
          child: const Text("About"),
        ),
      ),
    );
  }
}
