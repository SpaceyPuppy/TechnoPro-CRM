import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A full-width list with a slide-in detail panel from the right.
///
/// The list always occupies the full width. When [selectedId] is non-null
/// a panel slides in from the right (560px on desktop, full-screen on narrow)
/// with a semi-transparent scrim behind it. Clicking the scrim or pressing
/// Escape calls [onDismiss].
class SidePanel extends StatelessWidget {
  const SidePanel({
    super.key,
    required this.child,
    required this.selectedId,
    required this.panelBuilder,
    required this.onDismiss,
    this.panelWidth = 560.0,
  });

  /// The full-width list content shown behind the panel.
  final Widget child;

  /// When non-null the panel is open showing this id's detail.
  final String? selectedId;

  /// Builds the panel content for a given id.
  final Widget Function(String id) panelBuilder;

  /// Called when the user dismisses the panel (scrim tap or Escape).
  final VoidCallback onDismiss;

  /// Maximum panel width on wide screens. Defaults to 560.
  final double panelWidth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isOpen = selectedId != null;
    final effectivePanelWidth = screenWidth < panelWidth ? screenWidth : panelWidth;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (isOpen) onDismiss();
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            // Layer 1: full-width list
            Positioned.fill(child: child),

            // Layer 2: scrim
            AnimatedOpacity(
              opacity: isOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: isOpen
                  ? GestureDetector(
                      onTap: onDismiss,
                      child: Container(color: Colors.black.withValues(alpha: 0.35)),
                    )
                  : const SizedBox.shrink(),
            ),

            // Layer 3: sliding panel
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              top: 0,
              bottom: 0,
              right: isOpen ? 0 : -effectivePanelWidth,
              width: effectivePanelWidth,
              child: Material(
                elevation: 16,
                shadowColor: Colors.black38,
                child: isOpen
                    ? panelBuilder(selectedId!)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful shell that owns [selectedId] and wires a list screen to a
/// [SidePanel]. Use this in the router where [AdaptiveSplitView] was used.
class SidePanelShell extends StatefulWidget {
  const SidePanelShell({
    super.key,
    required this.listBuilder,
    required this.panelBuilder,
    this.panelWidth = 560.0,
  });

  /// Receives [selectedId] and [onSelect] — same signature as AdaptiveSplitView.
  final Widget Function(String? selectedId, void Function(String id) onSelect) listBuilder;
  final Widget Function(String id) panelBuilder;
  final double panelWidth;

  @override
  State<SidePanelShell> createState() => _SidePanelShellState();
}

class _SidePanelShellState extends State<SidePanelShell> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return SidePanel(
      selectedId: _selectedId,
      panelBuilder: widget.panelBuilder,
      panelWidth: widget.panelWidth,
      onDismiss: () => setState(() => _selectedId = null),
      child: widget.listBuilder(
        _selectedId,
        (id) => setState(() => _selectedId = _selectedId == id ? null : id),
      ),
    );
  }
}
