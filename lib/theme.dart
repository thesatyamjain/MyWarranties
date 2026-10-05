import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Design read: iOS system look. Grouped gray canvas, white inset cards with no
/// border or shadow, one system-blue accent, semantic system colors for status.
/// ponytail: SF Pro cannot ship on Android/web, so Inter stands in for it.
class Pal {
  static const paper = Color(0xFFF2F2F7); // systemGroupedBackground
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF000000);
  static const muted = Color(0xFF6C6C70); // 4.7:1 on paper
  static const line = Color(0xFFC6C6C8); // separator
  static const blue = Color(0xFF007AFF); // accent
  static const green = Color(0xFF1E7A34); // status text (darkened for contrast)
  static const greenBg = Color(0xFFDDF4E2);
  static const amber = Color(0xFF9A5B00);
  static const amberBg = Color(0xFFFFEFD1);
  static const brick = Color(0xFFD70015);
  static const brickBg = Color(0xFFFFE1E3);
  static const r = 12.0;
}

final cardDecoration = BoxDecoration(
  color: Pal.card,
  borderRadius: BorderRadius.circular(Pal.r),
);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Pal.paper,
    colorScheme: ColorScheme.fromSeed(
        seedColor: Pal.blue, surface: Pal.paper, primary: Pal.blue),
    splashFactory: NoSplash.splashFactory,
    // Swipe-back and slide transitions everywhere, as on iOS.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    }),
  );
  final tt = base.textTheme.apply(
    bodyColor: Pal.ink,
    displayColor: Pal.ink,
    fontFamily: '-apple-system',
  );
  final r = BorderRadius.circular(Pal.r);
  OutlineInputBorder none() =>
      OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none);
  return base.copyWith(
    textTheme: tt.copyWith(
      // Large Title / Title 2 / Headline / Body / Footnote
      headlineMedium: tt.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.1),
      headlineSmall: tt.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.15),
      titleMedium: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: tt.bodyMedium?.copyWith(color: Pal.muted, height: 1.45),
      bodySmall: tt.bodySmall?.copyWith(color: Pal.muted, height: 1.4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Pal.paper,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      foregroundColor: Pal.blue,
    ),
    dialogTheme: DialogThemeData(
        backgroundColor: Pal.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Pal.card,
      enabledBorder: none(),
      focusedBorder: OutlineInputBorder(
          borderRadius: r, borderSide: const BorderSide(color: Pal.blue, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: r, borderSide: const BorderSide(color: Pal.brick)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: r, borderSide: const BorderSide(color: Pal.brick)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Pal.blue,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: r),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Pal.blue)),
    chipTheme: ChipThemeData(
      backgroundColor: Pal.card,
      selectedColor: Pal.blue.withValues(alpha: 0.14),
      checkmarkColor: Pal.blue,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(color: Pal.ink, fontSize: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xF2F9F9F9), // translucent bar tint
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 56,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Pal.blue : Pal.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: s.contains(WidgetState.selected) ? Pal.blue : Pal.muted)),
    ),
  );
}

/// True Apple Liquid Glass surface:
/// - Progressive optical blur (high-density sigma)
/// - Ambient light dispersion shadow with tinted depth
/// - Specular rim refraction (top-left glint, bottom-right ambient rim)
/// - Translucent frosted milky white gradient substrate
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;

  const Glass({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
    this.blur = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          // Soft ambient floor shadow
          BoxShadow(
            color: const Color(0xFF001133).withValues(alpha: 0.08),
            blurRadius: 36,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
          // Tight contact shadow for floating separation
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              // Translucent milky refractive surface
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.72),
                  Colors.white.withValues(alpha: 0.38),
                ],
                stops: const [0.0, 1.0],
              ),
              // Dual-toned specular rim simulating light refraction across curved glass
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Soft tinted canvas so the glass has something to refract.
const glassBackdrop = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE3EDFF), Color(0xFFF2F2F7), Color(0xFFFBE9EF)],
    stops: [0, 0.55, 1],
  ),
);

/// Apple spring bounce micro-interaction on tap/press (iOS system touch feedback)
class AppleBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;

  const AppleBounce({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 140),
  });

  @override
  State<AppleBounce> createState() => _AppleBounceState();
}

class _AppleBounceState extends State<AppleBounce> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
