import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern dark dating-app palette: deep midnight purple + magenta + cyan accent.
class AzarPalette {
  // Surfaces — layered depth
  static const Color bg          = Color(0xFF0A0612); // deepest
  static const Color surface     = Color(0xFF14101F); // card surface
  static const Color surfaceUp   = Color(0xFF1F1830); // elevated card
  static const Color surfaceHigh = Color(0xFF2A2240); // hovered / pressed
  static const Color line        = Color(0xFF2A2440); // 1px dividers
  static const Color lineDim     = Color(0xFF1C1730); // subtle dividers

  // Text
  static const Color text      = Color(0xFFF5F1FF);
  static const Color textDim   = Color(0xFF9A92B0);
  static const Color textFaint = Color(0xFF5A5470);

  // Accents
  static const Color primary   = Color(0xFFFF3E7F); // hot magenta
  static const Color primaryUp = Color(0xFFFF5C97); // hover state
  static const Color secondary = Color(0xFF00E5FF); // electric cyan
  static const Color danger    = Color(0xFFFF4D5E);
  static const Color warning   = Color(0xFFFFB547);
  static const Color success   = Color(0xFF00C896);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF3E7F), Color(0xFFB13EFF)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F1830), Color(0xFF14101F)],
  );

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF130824), Color(0xFF0A0612)],
  );

  // Legacy aliases (old code paths still reference these)
  static const Color accent = primary;
}

ThemeData buildAzarTheme() {
  final base = GoogleFonts.interTextTheme(const TextTheme(
    displayLarge:  TextStyle(fontSize: 56, height: 1.05, letterSpacing: -1.5, fontWeight: FontWeight.w800, color: AzarPalette.text),
    displayMedium: TextStyle(fontSize: 42, height: 1.1,  letterSpacing: -1.0, fontWeight: FontWeight.w800, color: AzarPalette.text),
    headlineLarge: TextStyle(fontSize: 32, height: 1.15, letterSpacing: -0.6, fontWeight: FontWeight.w700, color: AzarPalette.text),
    headlineSmall: TextStyle(fontSize: 22, height: 1.2,  letterSpacing: -0.3, fontWeight: FontWeight.w600, color: AzarPalette.text),
    titleLarge:    TextStyle(fontSize: 18, height: 1.25, letterSpacing: -0.2, fontWeight: FontWeight.w600, color: AzarPalette.text),
    bodyLarge:     TextStyle(fontSize: 16, height: 1.45,                       color: AzarPalette.text),
    bodyMedium:    TextStyle(fontSize: 14, height: 1.45,                       color: AzarPalette.textDim),
    bodySmall:     TextStyle(fontSize: 12, height: 1.3,  letterSpacing: 0.3,   color: AzarPalette.textFaint),
    labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AzarPalette.text),
  ));

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AzarPalette.bg,
    colorScheme: const ColorScheme.dark(
      primary:    AzarPalette.primary,
      onPrimary:  Colors.white,
      secondary:  AzarPalette.secondary,
      onSecondary: Color(0xFF002A2F),
      surface:    AzarPalette.surface,
      onSurface:  AzarPalette.text,
      error:      AzarPalette.danger,
    ),
    textTheme: base,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AzarPalette.primary,
      linearTrackColor: AzarPalette.surfaceHigh,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AzarPalette.surfaceUp,
      contentTextStyle: TextStyle(color: AzarPalette.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Reusable rounded gradient pill — the canonical primary CTA.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.height = 56,
    this.gradient = AzarPalette.brandGradient,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  final double height;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null || busy;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: height,
        decoration: BoxDecoration(
          gradient: disabled ? null : gradient,
          color: disabled ? AzarPalette.surfaceHigh : null,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: AzarPalette.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: busy
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Outlined / ghost button — secondary CTA.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = 56,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AzarPalette.surface,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: AzarPalette.line, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: disabled ? AzarPalette.textFaint : AzarPalette.text, size: 20),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: disabled ? AzarPalette.textFaint : AzarPalette.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass card — translucent surface with subtle border, used for inset content.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 24});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AzarPalette.surfaceGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AzarPalette.line, width: 1),
      ),
      child: child,
    );
  }
}

/// Background scaffold with subtle radial highlight.  Use in place of plain Scaffold body.
class AzarBackground extends StatelessWidget {
  const AzarBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AzarPalette.bgGradient),
      child: Stack(
        children: [
          // soft top-right magenta glow
          Positioned(
            top: -120, right: -100,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AzarPalette.primary.withValues(alpha: 0.22),
                    AzarPalette.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // soft bottom-left cyan glow
          Positioned(
            bottom: -160, left: -120,
            child: Container(
              width: 360, height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AzarPalette.secondary.withValues(alpha: 0.10),
                    AzarPalette.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
