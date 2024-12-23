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
import 'package:provider/single_child_widget.dart';

void showAboutPopup(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: "Tabula Historica",
    children: const [
      _AboutContents(),
    ]
  );
}

class _AboutContents extends StatelessWidget {
  const _AboutContents();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Text("Usage", style: theme.textTheme.titleMedium)),
        const Center(
          child: SizedBox(
            width: 64,
            child: Divider(),
          ),
        ),
        Text("Scroll to zoom in and out", style: theme.textTheme.bodyLarge,),
        Text("Drag to pan", style: theme.textTheme.bodyLarge,),
        Text("Click any label to view more information", style: theme.textTheme.bodyLarge,),
        Text("Scrub the timeline to view different time periods", style: theme.textTheme.bodyLarge,),
      ],
    );
  }
}

class AboutPopupShower extends SingleChildStatefulWidget {
  const AboutPopupShower({super.key, super.child});

  @override
  State<AboutPopupShower> createState() => _AboutPopupShowerState();
}

class _AboutPopupShowerState extends SingleChildState<AboutPopupShower> {
  bool _shown = false;

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    if (!_shown) {
      _shown = true;
      scheduleMicrotask(() {
        if (Uri.base.queryParameters.containsKey("about") || Uri.base.queryParameters.containsKey("showAbout")) {
          showAboutPopup(context);
        }
      });
    }
    return child ?? const SizedBox.shrink();
  }
}
