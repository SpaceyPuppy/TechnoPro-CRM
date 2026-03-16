import 'dart:io' show Platform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/providers/layout_provider.dart';
import 'core/router/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TechnoProApp()));
}

class TechnoProApp extends ConsumerWidget {
  const TechnoProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;

    return MaterialApp.router(
      title: 'TechnoPro CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(baseTextTheme),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      // Allow mouse-drag scrolling on desktop
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
        },
      ),
      routerConfig: router,
      builder: (context, child) => _TouchDetector(child: child!),
    );
  }
}

/// Listens for pointer-device kind on Windows/desktop and updates [touchModeProvider].
/// On Android/iOS this is a no-op (always touch).
class _TouchDetector extends ConsumerWidget {
  const _TouchDetector({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid || Platform.isIOS) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final isTouch = event.kind == PointerDeviceKind.touch ||
            event.kind == PointerDeviceKind.stylus;
        ref.read(touchModeProvider.notifier).state = isTouch;
      },
      child: child,
    );
  }
}
