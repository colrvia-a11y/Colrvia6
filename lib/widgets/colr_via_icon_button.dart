import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Unified icon button supporting outlined and filled styles with busy state and haptics.
enum ColrViaIconButtonStyle { outline, filled }

class ColrViaIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool busy;
  final double size;
  final double borderRadius;
  final double borderWidth;
  final ColrViaIconButtonStyle style;
  final String? semanticLabel;

  const ColrViaIconButton({
    super.key,
    required this.icon,
    required this.color,
    this.iconColor,
    this.backgroundColor,
    this.onPressed,
    this.busy = false,
    this.size = 44,
    this.borderRadius = 12,
    this.borderWidth = 1.2,
    this.style = ColrViaIconButtonStyle.outline,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = style == ColrViaIconButtonStyle.filled;
    final r = BorderRadius.circular(borderRadius);
    final Color bg = isFilled ? color : (backgroundColor ?? Colors.transparent);
    final Color fg = iconColor ??
        (isFilled
            ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? Colors.white
                : Colors.black)
            : color);

    Widget button = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: r,
        side: isFilled
            ? BorderSide.none
            : BorderSide(color: color.withAlpha(150), width: borderWidth),
      ),
      child: InkWell(
        borderRadius: r,
        splashColor: fg.withAlpha(60),
        highlightColor: fg.withAlpha(24),
        hoverColor: fg.withAlpha(12),
        focusColor: fg.withAlpha(24),
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Icon(icon, color: fg),
          ),
        ),
      ),
    );

    if (semanticLabel != null) {
      button = Tooltip(
        message: semanticLabel!,
        child: button,
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: button,
    );
  }
}
