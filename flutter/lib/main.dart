import 'dart:io' show Platform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/providers/layout_provider.dart';
import 'core/router/router.dart';

class DesktopScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Android/iOS: Bouncing physics for elastic scroll feel
    // Windows/macOS: ClampingScrollPhysics for smooth momentum + mouse/trackpad support
    if (Platform.isAndroid || Platform.isIOS) {
      return const BouncingScrollPhysics();
    }
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TechnoProApp()));
}

class TechnoProApp extends ConsumerWidget {
  const TechnoProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'First Choice Phone Repair',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      scrollBehavior: DesktopScrollBehavior(),
      routerConfig: router,
      builder: (context, child) => _TouchDetector(child: child!),
    );
  }

  ThemeData _buildTheme() {
    const primary = Color(0xFF1D4ED8);
    const primaryContainer = Color(0xFFDBEAFE);
    const surface = Color(0xFFF8FAFC);
    const surfaceContainer = Color(0xFFFFFFFF);
    const outline = Color(0xFFCBD5E1);

    final base = ThemeData(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      primaryContainer: primaryContainer,
      surface: surface,
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF1F5F9),
      surfaceContainer: const Color(0xFFE2E8F0),
      surfaceContainerHigh: const Color(0xFFCBD5E1),
      outline: const Color(0xFF94A3B8),
      outlineVariant: outline,
      onSurfaceVariant: const Color(0xFF475569),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surfaceContainer,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF475569)),
        shape: const Border(
          bottom: BorderSide(color: outline),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceContainer,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: outline),
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: outline,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
    );
  }
}

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
