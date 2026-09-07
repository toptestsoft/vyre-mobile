import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

// ─── GlassCard ───
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final Color? tint;
  final Border? border;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.tint,
    this.border,
    this.shadows,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius!),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tint ?? kGlass,
              borderRadius: BorderRadius.circular(radius!),
              border: border ?? Border.all(color: kGlassBorder, width: 1),
              boxShadow: shadows ?? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── GradientText ───
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color> colors;
  final TextAlign? textAlign;

  const GradientText(this.text, {super.key, required this.style, required this.colors, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}

// ─── GlassIconButton ───
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kGlass,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kGlassBorder),
          ),
          child: Icon(icon, color: kTextSecondary, size: 17),
        ),
      ),
    );
  }
}

// ─── AmbientOrb ───
class AmbientOrb extends StatelessWidget {
  final double size;
  final Color? color;
  final double opacity;

  const AmbientOrb({super.key, this.size = 120, this.color, this.opacity = 0.3});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (color ?? kAccentCyan).withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: (color ?? kAccentCyan).withValues(alpha: opacity),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}
