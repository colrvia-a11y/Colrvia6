import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App-wide outlined icon button with busy state, matching ripple, and haptics.
class AppOutlineIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool busy;
  final double size;
  final double borderRadius;
  final double borderWidth;

  const AppOutlineIconButton({
    super.key,
    required this.icon,
    required this.color,
    this.onPressed,
    this.busy = false,
    this.size = 44,
    this.borderRadius = 10,
    this.borderWidth = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(borderRadius);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: r,
        side: BorderSide(color: color.withAlpha(150), width: borderWidth),
      ),
      child: InkWell(
        borderRadius: r,
        splashColor: color.withAlpha(60),
        highlightColor: color.withAlpha(24),
        hoverColor: color.withAlpha(12),
        focusColor: color.withAlpha(24),
        onTap: busy
            ? null
            : () async {
                try {
                  await HapticFeedback.lightImpact();
                } catch (_) {}
                onPressed?.call();
              },
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: busy
                ? SizedBox(
                    width: size * 0.4,
                    height: size * 0.4,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  )
                : Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}

