import 'package:flutter/material.dart';

/// Shows a split list/detail layout on wide screens (>= 900px),
/// or just the list on narrow screens (navigation handled by go_router).
class AdaptiveSplitView extends StatefulWidget {
  const AdaptiveSplitView({
    super.key,
    required this.listBuilder,
    required this.detailBuilder,
    this.emptyDetail,
    this.breakpoint = 900,
    this.listWidth = 360,
  });

  final Widget Function(String? selectedId, void Function(String id)? onSelect) listBuilder;
  final Widget Function(String id) detailBuilder;
  final Widget? emptyDetail;
  final double breakpoint;
  final double listWidth;

  @override
  State<AdaptiveSplitView> createState() => _AdaptiveSplitViewState();
}

class _AdaptiveSplitViewState extends State<AdaptiveSplitView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= widget.breakpoint;

    if (!isWide) {
      // Narrow: list only, go_router handles navigation on tap
      return widget.listBuilder(null, null);
    }

    // Wide: side-by-side split view
    return Row(
      children: [
        SizedBox(
          width: widget.listWidth,
          child: widget.listBuilder(
            _selectedId,
            (id) => setState(() => _selectedId = id),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedId != null
              ? widget.detailBuilder(_selectedId!)
              : widget.emptyDetail ??
                  const Center(
                    child: Text('Select an item', style: TextStyle(color: Colors.grey)),
                  ),
        ),
      ],
    );
  }
}
