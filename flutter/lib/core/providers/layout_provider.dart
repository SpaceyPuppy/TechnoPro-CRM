import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the UI should render in touch mode.
/// Defaults to true on Android/iOS, false on Windows/macOS/Linux.
/// Updated at runtime in main.dart via pointer-device detection.
final touchModeProvider = StateProvider<bool>((ref) {
  return Platform.isAndroid || Platform.isIOS;
});

enum LayoutTier { phone, tablet, desktop }

/// Determines layout tier from screen width and touch mode.
///
/// - desktop: width >= 1100 AND not touch → dense tables, extended sidebar
/// - tablet:  width >= 600  OR  touch on wide screen → touch-friendly cards, nav rail
/// - phone:   width < 600 → bottom nav, single pane
LayoutTier layoutTier(double width, bool isTouch) {
  if (width >= 1100 && !isTouch) return LayoutTier.desktop;
  if (width >= 600) return LayoutTier.tablet;
  return LayoutTier.phone;
}
