import 'dart:io' show Platform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth/auth_provider.dart';
import 'core/providers/layout_provider.dart';
import 'core/router/router.dart';
import 'core/sync/connectivity_service.dart';
import 'core/sync/sync_service.dart';

class _SmoothDesktopScrollPhysics extends ClampingScrollPhysics {
  const _SmoothDesktopScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  _SmoothDesktopScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SmoothDesktopScrollPhysics(parent: buildParent(ancestor));
  }

}

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
    // Windows/macOS: Custom smooth scroll physics with adjusted friction for trackpad momentum
    if (Platform.isAndroid || Platform.isIOS) {
      return const BouncingScrollPhysics();
    }
    return const _SmoothDesktopScrollPhysics();
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

class TechnoProApp extends ConsumerStatefulWidget {
  const TechnoProApp({super.key});

  @override
  ConsumerState<TechnoProApp> createState() => _TechnoProAppState();
}

class _TechnoProAppState extends ConsumerState<TechnoProApp> {
  late final ProviderSubscription<bool> _authSubscription;

  @override
  void initState() {
    super.initState();
    ref.read(connectivityServiceProvider);
    _authSubscription = ref.listenManual<bool>(
      authProvider.select((state) => state.isAuthenticated),
      (previous, authenticated) {
        if (authenticated && previous != true) {
          ref.read(syncServiceProvider).syncAll();
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _authSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'First Choice Phone Repair',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      scrollBehavior: DesktopScrollBehavior(),
      routerConfig: router,
      builder: (context, child) => _TouchDetector(child: child!),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const primary = Color(0xFF1D4ED8);
    final isDark = brightness == Brightness.dark;
    final primaryContainer = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    final surface = isDark ? const Color(0xFF101521) : const Color(0xFFF6F8FC);
    final surfaceContainer = isDark ? const Color(0xFF192131) : const Color(0xFFFFFFFF);
    final outline = isDark ? const Color(0xFF34425A) : const Color(0xFFCBD5E1);
    final onSurface = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final onSurfaceVariant = isDark ? const Color(0xFFB8C3D8) : const Color(0xFF475569);

    final base = ThemeData(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      primaryContainer: primaryContainer,
      surface: surface,
      surfaceContainerLowest: surfaceContainer,
      surfaceContainerLow: isDark ? const Color(0xFF151C2A) : const Color(0xFFF1F5F9),
      surfaceContainer: isDark ? const Color(0xFF202A3C) : const Color(0xFFE2E8F0),
      surfaceContainerHigh: isDark ? const Color(0xFF2B374B) : const Color(0xFFCBD5E1),
      outline: isDark ? const Color(0xFF5F6E87) : const Color(0xFF94A3B8),
      outlineVariant: outline,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
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
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurfaceVariant),
        shape: Border(
          bottom: BorderSide(color: outline.withValues(alpha: .7)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceContainer,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: outline.withValues(alpha: .72)),
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: .72),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 4,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceContainer,
        modalBackgroundColor: surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
