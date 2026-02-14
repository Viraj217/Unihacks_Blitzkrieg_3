import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final Color? borderColor;
  final double borderHighlightOpacity;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.blur = 15,
    this.opacity = 0.1,
    this.color,
    this.borderColor,
    this.borderHighlightOpacity = 0.2, // Subtle white border
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(20);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(boxShadow: boxShadow, borderRadius: br),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(opacity),
              borderRadius: br,
              border: Border.all(
                color:
                    borderColor ??
                    Colors.white.withOpacity(borderHighlightOpacity),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (color ?? Colors.white).withOpacity(
                    (opacity + 0.05).clamp(0.0, 1.0),
                  ),
                  (color ?? Colors.white).withOpacity(
                    (opacity - 0.02).clamp(0.0, 1.0),
                  ),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
