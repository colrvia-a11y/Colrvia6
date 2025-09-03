import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

/// Enhanced floating action menu that appears on long press
class ColorStripActionMenu extends StatefulWidget {
  final Paint paint;
  final VoidCallback? onDelete;
  final VoidCallback? onDetails;
  final VoidCallback? onCopy;
  final VoidCallback? onPin;
  final VoidCallback? onReplace;
  final VoidCallback onDismiss;

  const ColorStripActionMenu({
    super.key,
    required this.paint,
    this.onDelete,
    this.onDetails,
    this.onCopy,
    this.onPin,
    this.onReplace,
    required this.onDismiss,
  });

  @override
  State<ColorStripActionMenu> createState() => _ColorStripActionMenuState();
}

class _ColorStripActionMenuState extends State<ColorStripActionMenu>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissWithAnimation() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissWithAnimation,
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          width: 280,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Color preview
                              Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Color(int.parse(widget.paint.hex.replaceAll('#', ''), radix: 16) | 0xFF000000),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    widget.paint.name,
                                    style: TextStyle(
                                      color: _getTextColor(),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Action buttons in a grid
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (widget.onDetails != null)
                                    _ActionButton(
                                      icon: Icons.info_outline,
                                      label: 'Details',
                                      onTap: () {
                                        _dismissWithAnimation();
                                        widget.onDetails!();
                                      },
                                    ),
                                  if (widget.onCopy != null)
                                    _ActionButton(
                                      icon: Icons.copy_outlined,
                                      label: 'Copy',
                                      onTap: () {
                                        _dismissWithAnimation();
                                        widget.onCopy!();
                                      },
                                    ),
                                  if (widget.onPin != null)
                                    _ActionButton(
                                      icon: Icons.push_pin_outlined,
                                      label: 'Pin',
                                      onTap: () {
                                        _dismissWithAnimation();
                                        widget.onPin!();
                                      },
                                    ),
                                  if (widget.onReplace != null)
                                    _ActionButton(
                                      icon: Icons.palette_outlined,
                                      label: 'Replace',
                                      onTap: () {
                                        _dismissWithAnimation();
                                        widget.onReplace!();
                                      },
                                    ),
                                  if (widget.onDelete != null)
                                    _ActionButton(
                                      icon: Icons.delete_outline,
                                      label: 'Delete',
                                      onTap: () {
                                        _dismissWithAnimation();
                                        widget.onDelete!();
                                      },
                                      isDestructive: true,
                                    ),
                                ],
                              ),
                              
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _dismissWithAnimation,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTextColor() {
    final colorValue = int.parse(widget.paint.hex.replaceAll('#', ''), radix: 16);
    final color = Color(0xFF000000 | colorValue);
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : Theme.of(context).primaryColor;
    
    return SizedBox(
      width: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
