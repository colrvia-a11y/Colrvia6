// 🎨 LUXE COLOR PICKER 2030
// Award-winning color selection interface for the AI Visualizer

import 'package:flutter/material.dart';

class LuxeColorPicker extends StatefulWidget {
  final String initialColor;
  final List<String> recentColors;
  final List<String> paletteColors;
  final Function(String) onColorSelected;
  final VoidCallback onClose;

  const LuxeColorPicker({
    super.key,
    required this.initialColor,
    required this.recentColors,
    required this.paletteColors,
    required this.onColorSelected,
    required this.onClose,
  });

  @override
  State<LuxeColorPicker> createState() => _LuxeColorPickerState();
}

class _LuxeColorPickerState extends State<LuxeColorPicker>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _rippleController;
  late Animation<double> _slideAnimation;

  String _selectedColor = '';
  bool _showCustomPicker = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: _closeModal,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),

          // Modal
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0,
                    MediaQuery.of(context).size.height * _slideAnimation.value),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF404934), // Brand forest green
                          Color(0xFF2F3728), // Deeper forest
                          Color(0xFF1F251A), // Rich organic dark
                        ],
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: _buildModalContent(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModalContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Text(
                'Choose Color',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _closeModal,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),

        // Content
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Selection
                _buildCurrentSelection(),
                const SizedBox(height: 32),

                // Palette Colors
                if (widget.paletteColors.isNotEmpty) ...[
                  _buildSectionTitle('Palette Colors'),
                  const SizedBox(height: 16),
                  _buildColorGrid(widget.paletteColors, 'palette'),
                  const SizedBox(height: 32),
                ],

                // Recent Colors
                if (widget.recentColors.isNotEmpty) ...[
                  _buildSectionTitle('Recent Colors'),
                  const SizedBox(height: 16),
                  _buildColorGrid(widget.recentColors, 'recent'),
                  const SizedBox(height: 32),
                ],

                // Popular Colors
                _buildSectionTitle('Popular Colors'),
                const SizedBox(height: 16),
                _buildColorGrid(_getPopularColors(), 'popular'),
                const SizedBox(height: 32),

                // Custom Color Button
                _buildCustomColorButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Apply Button
        _buildApplyButton(),
      ],
    );
  }

  Widget _buildCurrentSelection() {
    final color = _parseColor(_selectedColor);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Color Preview
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Color Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Color',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedColor.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontFamily: 'Courier',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getColorName(_selectedColor),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildColorGrid(List<String> colors, String category) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) =>
          _buildColorOption(colors[index], category),
    );
  }

  Widget _buildColorOption(String colorHex, String category) {
    final color = _parseColor(colorHex);
    final isSelected = _selectedColor.toLowerCase() == colorHex.toLowerCase();

    return GestureDetector(
      onTap: () => _selectColor(colorHex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(isSelected ? 16 : 12),
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _buildCustomColorButton() {
    return GestureDetector(
      onTap: () => setState(() => _showCustomPicker = !_showCustomPicker),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF2B897),
              Color(0xFFE5A177)
            ], // Brand peach gradient
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF2B897)
                  .withValues(alpha: 0.3), // Brand peach glow
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.colorize, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Custom Color Picker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              _showCustomPicker ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _applyColor,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF404934), // Brand forest green
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Apply Color',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _selectColor(String colorHex) {
    setState(() => _selectedColor = colorHex);
    _rippleController.forward().then((_) => _rippleController.reset());
  }

  void _applyColor() {
    widget.onColorSelected(_selectedColor);
    _closeModal();
  }

  void _closeModal() {
    _slideController.reverse().then((_) => widget.onClose());
  }

  Color _parseColor(String colorHex) {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  String _getColorName(String colorHex) {
    // Simple color name mapping - in production, use a comprehensive color database
    final colorNames = {
      '#FFFFFF': 'Pure White',
      '#F5F5F5': 'Soft White',
      '#E0E0E0': 'Light Gray',
      '#CCCCCC': 'Silver',
      '#999999': 'Medium Gray',
      '#666666': 'Dark Gray',
      '#333333': 'Charcoal',
      '#000000': 'Black',
      '#FF6B35': 'Coral',
      '#F7931E': 'Orange',
      '#FFD23F': 'Golden Yellow',
      '#06FFA5': 'Mint Green',
      '#118AB2': 'Ocean Blue',
      '#073B4C': 'Navy',
    };

    return colorNames[colorHex.toUpperCase()] ?? 'Custom Color';
  }

  List<String> _getPopularColors() {
    return [
      '#FFFFFF',
      '#F8F9FA',
      '#E9ECEF',
      '#DEE2E6',
      '#CED4DA',
      '#ADB5BD',
      '#6C757D',
      '#495057',
      '#343A40',
      '#212529',
      '#000000',
      '#F8F9FA',
      '#E3F2FD',
      '#BBDEFB',
      '#90CAF9',
      '#64B5F6',
      '#42A5F5',
      '#2196F3',
      '#1E88E5',
      '#1976D2',
      '#1565C0',
      '#0D47A1',
      '#0277BD',
      '#01579B',
      '#E8F5E8',
      '#C8E6C9',
      '#A5D6A7',
      '#81C784',
      '#66BB6A',
      '#4CAF50',
      '#43A047',
      '#388E3C',
      '#2E7D32',
      '#1B5E20',
      '#2E7D32',
      '#1B5E20',
      '#FFF3E0',
      '#FFE0B2',
      '#FFCC80',
      '#FFB74D',
      '#FFA726',
      '#FF9800',
      '#FB8C00',
      '#F57C00',
      '#EF6C00',
      '#E65100',
      '#FF8F00',
      '#FF6F00',
    ];
  }

  @override
  void dispose() {
    _slideController.dispose();
    _rippleController.dispose();
    super.dispose();
  }
}
