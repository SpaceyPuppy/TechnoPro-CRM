import 'package:flutter/material.dart';

import 'prism_surfaces.dart';

export 'prism_surfaces.dart';

/// Shared page chrome for the operations app. It deliberately avoids a stock
/// Material toolbar: all feature pages receive the same clear title hierarchy,
/// glass action rail and predictable return affordance.
class PrismAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrismAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.toolbarHeight = 64,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;
  final bool centerTitle;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + 14 + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final resolvedLeading = leading ??
        (automaticallyImplyLeading && canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrismSurface(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                height: toolbarHeight - 16,
                child: Row(
                  children: [
                    if (resolvedLeading != null) resolvedLeading,
                    Expanded(
                      child: Align(
                        alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
                        child: DefaultTextStyle.merge(
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.35,
                              ),
                          child: title ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            ),
            if (bottom != null) ...[
              const SizedBox(height: 6),
              SizedBox(height: bottom!.preferredSize.height, child: bottom!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gives a workspace a deliberate edge and maximum reading width instead of
/// letting lists and forms float against the canvas like a stock Material page.
class PrismPageBody extends StatelessWidget {
  const PrismPageBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.maxWidth = 1240,
    this.surface = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final bool surface;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: surface
          ? PrismSurface(radius: 28, child: child)
          : child,
    );
    return Padding(
      padding: padding,
      child: Center(child: content),
    );
  }
}

/// A dense, readable section header shared by operational lists and detail
/// views. It adds hierarchy without returning to large card-grid dashboards.
class PrismSectionLabel extends StatelessWidget {
  const PrismSectionLabel({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: subtitle == null ? 22 : 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: [colors.primary, const Color(0xFF67E8F9)],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
