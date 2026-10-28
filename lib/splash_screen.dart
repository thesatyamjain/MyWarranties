import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'theme.dart';

/// Design Read: Apple Liquid Glass brand entrance.
/// Ethereal luminous ambient canvas with seamless launch handoff (#ECF0F9),
/// floating frosted glass shield vault emblem with specular glint sweep,
/// tight display typography, and a fluid exponential ease-out reveal.
class SplashWrapper extends StatefulWidget {
  final Store store;
  final Widget child;
  final bool enabled;

  const SplashWrapper({
    super.key,
    required this.store,
    required this.child,
    this.enabled = true,
  });

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _shimmerAnimation;
  late final Animation<double> _exitFadeAnimation;

  bool _isExiting = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _finished = true;
      return;
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Initial entrance scale & fade (0ms - 550ms)
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // Specular glint sweep across the glass shield (300ms - 850ms)
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.75, curve: Curves.easeInOutCubic),
      ),
    );

    // Exit fade (1050ms - 1400ms)
    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOutQuart),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) {
        setState(() => _finished = true);
      }
    });
  }

  void _skip() {
    if (_finished || _isExiting) return;
    _isExiting = true;
    HapticFeedback.lightImpact();
    _controller.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut).then((_) {
      if (mounted) setState(() => _finished = true);
    });
  }

  @override
  void dispose() {
    if (widget.enabled) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;

    return Stack(
      children: [
        // App workspace beneath
        widget.child,

        // Fluid luxury splash overlay
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Opacity(
              opacity: _exitFadeAnimation.value.clamp(0.0, 1.0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _skip,
                child: Scaffold(
                  backgroundColor: Pal.paper,
                  body: Stack(
                    children: [
                      // Subtle ambient glow orbs behind glass refraction
                      Positioned(
                        top: MediaQuery.of(context).size.height * 0.22,
                        left: MediaQuery.of(context).size.width * 0.5 - 130,
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Pal.blue.withValues(alpha: 0.16),
                                const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Center Hero Identity
                      Center(
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Liquid Glass Shield Vault
                                _LiquidGlassVaultEmblem(
                                  glintOffset: _shimmerAnimation.value,
                                ),
                                const SizedBox(height: 24),

                                // Brand Display Title
                                const Text(
                                  'My Warranties',
                                  style: TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.7,
                                    color: Pal.ink,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Subtle Glass Sub-brand Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.90),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'PRIVATE WARRANTY VAULT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.0,
                                      color: Pal.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom Trust & Privacy Assurance
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 36,
                        child: SafeArea(
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.70),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.lock_shield_fill,
                                        size: 13,
                                        color: Pal.green,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '100% On-Device · Encrypted Vault',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Pal.muted,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating Liquid Glass Shield Vault Emblem
class _LiquidGlassVaultEmblem extends StatelessWidget {
  final double glintOffset;

  const _LiquidGlassVaultEmblem({required this.glintOffset});

  @override
  Widget build(BuildContext context) {
    const double size = 104;
    final r = BorderRadius.circular(28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          // Soft ambient room floor shadow
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 32,
            spreadRadius: -2,
            offset: const Offset(0, 16),
          ),
          // Luminous specular tint
          BoxShadow(
            color: Pal.blue.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.58),
                ],
                stops: const [0.0, 0.40, 0.80, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: 1.4,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner soft refraction glow
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Pal.blue.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Shield Icon with dual-tone depth
                const Icon(
                  CupertinoIcons.checkmark_shield_fill,
                  size: 52,
                  color: Pal.blue,
                ),

                // Specular Glint Sheen sweep
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: r,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(-1.5 + glintOffset, -1.0),
                          end: Alignment(-0.5 + glintOffset, 1.0),
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0.75),
                            Colors.white.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.40, 0.50, 0.60, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
