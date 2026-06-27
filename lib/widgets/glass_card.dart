import 'dart:ui';

import 'package:flutter/material.dart';

/// Reusable frosted-glass surface: BackdropFilter blur + translucent fill +
/// 1px translucent-white border + soft shadow (§8.1).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur;
  final double radius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.blur = 18,
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: border,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: border,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: border,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
