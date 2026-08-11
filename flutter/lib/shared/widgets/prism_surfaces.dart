import 'dart:ui';

import 'package:flutter/material.dart';

/// The app canvas deliberately has colour and light behind it. A glass surface
/// needs a living backdrop; a flat scaffold makes even a blurred control read
/// as a grey Material card.
class PrismBackdrop extends StatelessWidget {
  const PrismBackdrop({super.key, required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF07111F) : const Color(0xFFF2F6FF);
    final cyan = dark ? const Color(0xFF0A6C88) : const Color(0xFF9CE8F4);
    final violet = dark ? const Color(0xFF5C3C91) : const Color(0xFFC9B7FF);
    final coral = dark ? const Color(0xFF8B4D64) : const Color(0xFFFFCFBD);

    return ColoredBox(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: compact ? -150 : -210,
            right: compact ? -120 : -160,
            child: _GlowOrb(color: cyan, size: compact ? 300 : 440),
          ),
          Positioned(
            bottom: compact ? -180 : -220,
            left: compact ? -150 : -180,
            child: _GlowOrb(color: violet, size: compact ? 340 : 500),
          ),
          Positioned(
            top: compact ? 220 : 180,
            left: compact ? -120 : 280,
            child: _GlowOrb(color: coral, size: compact ? 220 : 360),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: .74), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// A glossy, translucent surface used for navigation, controls and small
/// workspace groupings. Content cards stay selectively opaque for readability.
class PrismSurface extends StatelessWidget {
  const PrismSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = 24,
    this.onTap,
    this.tint,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? tint;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final fill = tint ?? (dark ? Colors.white.withValues(alpha: .095) : Colors.white.withValues(alpha: .64));
    final border = dark ? Colors.white.withValues(alpha: .23) : Colors.white.withValues(alpha: .82);
    final content = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape.copyWith(side: BorderSide(color: border)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fill.withValues(alpha: .94), fill.withValues(alpha: .54)],
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .24 : .12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: dark ? .08 : .68),
            blurRadius: 1,
            spreadRadius: .5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: onTap == null
              ? content
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(radius),
                    child: content,
                  ),
                ),
        ),
      ),
    );
  }
}

class PrismIconAction extends StatelessWidget {
  const PrismIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PrismSurface(
      radius: 18,
      onTap: onTap,
      semanticLabel: label,
      tint: selected ? colors.primary.withValues(alpha: .42) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: selected ? colors.primary : colors.onSurface),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
