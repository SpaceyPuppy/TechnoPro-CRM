import 'package:flutter/material.dart';

import 'prism_surfaces.dart';

/// Keeps data-entry focused: a full-height mobile workspace and a contained
/// sheet-like surface on tablet and desktop.
class AdaptiveFormScaffold extends StatelessWidget {
  const AdaptiveFormScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contained = constraints.maxWidth >= 600;
          if (!contained) return child;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: PrismSurface(
                  radius: 30,
                  tint: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: .58),
                  child: SizedBox(height: constraints.maxHeight - 48, child: child),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
