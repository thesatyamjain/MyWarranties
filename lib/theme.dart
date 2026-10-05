import 'dart:ui' show ImageFilter;

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

/// Liquid-glass surface: backdrop blur + saturation lift, a light-to-clear
/// gradient fill, a bright specular rim and a soft drop shadow.
/// ponytail: this is a blur-based approximation. True lensing/refraction needs
/// a fragment shader (e.g. the liquid_glass_renderer package).
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  const Glass(
      {super.key,
      required this.child,
      this.radius = 28,
      this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: const [
        BoxShadow(color: Color(0x26000000), blurRadius: 30, offset: Offset(0, 12)),
      ]),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.62),
                  Colors.white.withValues(alpha: 0.22),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1),
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
