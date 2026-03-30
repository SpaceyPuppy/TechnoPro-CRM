import 'package:flutter/material.dart';

/// Shows the pattern lock dialog and returns the pattern as a comma-separated
/// string e.g. "1,2,3,5,7,8,9", or null if cancelled.
Future<String?> showPatternLockDialog(BuildContext context, {String? initialPattern}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PatternLockDialog(initialPattern: initialPattern),
  );
}

/// Read-only widget that renders a saved pattern on a 3x3 dot grid.
class PatternLockDisplay extends StatelessWidget {
  const PatternLockDisplay({super.key, required this.pattern});

  final String pattern;

  @override
  Widget build(BuildContext context) {
    final nodes = pattern
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _PatternPainter(pattern: nodes, currentPos: null, color: color),
        child: Stack(
          children: [
            for (int node = 1; node <= 9; node++)
              _NodeDot(node: node, isActive: nodes.contains(node), isLast: false, size: 80),
          ],
        ),
      ),
    );
  }
}

class _PatternLockDialog extends StatefulWidget {
  const _PatternLockDialog({this.initialPattern});
  final String? initialPattern;

  @override
  State<_PatternLockDialog> createState() => _PatternLockDialogState();
}

class _PatternLockDialogState extends State<_PatternLockDialog> {
  List<int> _pattern = [];
  Offset? _currentPos;
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialPattern != null && widget.initialPattern!.isNotEmpty) {
      _pattern = widget.initialPattern!
          .split(',')
          .map(int.tryParse)
          .whereType<int>()
          .toList();
    }
  }

  static const _gridSize = 240.0;
  static const _padding = _gridSize * 0.15;
  static const _step = (_gridSize - _padding * 2) / 2;

  static Offset _nodeCenter(int node) {
    final row = (node - 1) ~/ 3;
    final col = (node - 1) % 3;
    return Offset(_padding + col * _step, _padding + row * _step);
  }

  int? _hitTest(Offset pos) {
    for (int node = 1; node <= 9; node++) {
      if ((pos - _nodeCenter(node)).distance < 28) return node;
    }
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(d.globalPosition);
    final hit = _hitTest(local);
    setState(() {
      _pattern = hit != null ? [hit] : [];
      _currentPos = local;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(d.globalPosition);
    final hit = _hitTest(local);
    setState(() {
      if (hit != null && !_pattern.contains(hit)) _pattern.add(hit);
      _currentPos = local;
    });
  }

  void _onPanEnd(DragEndDetails _) => setState(() => _currentPos = null);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Draw Pattern Lock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _pattern.isEmpty
                ? 'Draw your unlock pattern (min 3 points)'
                : 'Pattern: ${_pattern.join(",")}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: _gridSize,
            height: _gridSize,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                key: _key,
                painter: _PatternPainter(
                  pattern: _pattern,
                  currentPos: _currentPos,
                  color: colorScheme.primary,
                ),
                child: Stack(
                  children: [
                    for (int node = 1; node <= 9; node++)
                      _NodeDot(
                        node: node,
                        isActive: _pattern.contains(node),
                        isLast: _pattern.isNotEmpty && _pattern.last == node,
                        size: _gridSize,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _pattern = [];
            _currentPos = null;
          }),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _pattern.length >= 3
              ? () => Navigator.pop(context, _pattern.join(','))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _NodeDot extends StatelessWidget {
  const _NodeDot({
    required this.node,
    required this.isActive,
    required this.isLast,
    required this.size,
  });

  final int node;
  final bool isActive;
  final bool isLast;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final padding = size * 0.15;
    final step = (size - padding * 2) / 2;
    final row = (node - 1) ~/ 3;
    final col = (node - 1) % 3;
    final cx = padding + col * step;
    final cy = padding + row * step;
    const r = 20.0;

    return Positioned(
      left: cx - r,
      top: cy - r,
      child: Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
            width: isLast ? 2.5 : 1.5,
          ),
        ),
        child: Center(
          child: Text(
            '$node',
            style: TextStyle(
              fontSize: size > 100 ? 12 : 8,
              fontWeight: FontWeight.w600,
              color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({
    required this.pattern,
    required this.currentPos,
    required this.color,
  });

  final List<int> pattern;
  final Offset? currentPos;
  final Color color;

  Offset _nodeCenter(int node, Size size) {
    final row = (node - 1) ~/ 3;
    final col = (node - 1) % 3;
    final padding = size.width * 0.15;
    final step = (size.width - padding * 2) / 2;
    return Offset(padding + col * step, padding + row * step);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern.length < 2) return;
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < pattern.length - 1; i++) {
      canvas.drawLine(
        _nodeCenter(pattern[i], size),
        _nodeCenter(pattern[i + 1], size),
        linePaint,
      );
    }

    if (currentPos != null && pattern.isNotEmpty) {
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(_nodeCenter(pattern.last, size), currentPos!, dashPaint);
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.pattern != pattern || old.currentPos != currentPos;
}
