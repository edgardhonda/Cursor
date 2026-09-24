import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/stroke_widths.dart';

/// Paleta lateral — único controle além do desenho.
class ColorPalette extends StatelessWidget {
  const ColorPalette({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    required this.strokeLevel,
    required this.onStrokeLevelSelected,
    required this.isTablet,
    required this.onUndo,
    required this.onClearAll,
    required this.canUndo,
    required this.width,
    required this.pinned,
    required this.onTogglePin,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;
  final StrokeWidthLevel strokeLevel;
  final ValueChanged<StrokeWidthLevel> onStrokeLevelSelected;
  final bool isTablet;
  final VoidCallback onUndo;
  final VoidCallback onClearAll;
  final bool canUndo;
  final double width;
  final bool pinned;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: paletteBackground,
      child: SizedBox(
        width: width,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  itemCount: paletteColors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final color = paletteColors[index];
                    final isSelected = color.toARGB32() == selectedColor.toARGB32();
                    return _ColorButton(
                      color: color,
                      isSelected: isSelected,
                      onTap: () => onColorSelected(color),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: _StrokeWidthSelector(
                  selected: strokeLevel,
                  isTablet: isTablet,
                  onSelected: onStrokeLevelSelected,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: _UndoButton(onTap: onUndo, enabled: canUndo),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: _ClearButton(onTap: onClearAll),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
                child: _PinButton(pinned: pinned, onTap: onTogglePin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? const Color(0xFF1565C0) : const Color(0xFFBDBDBD);
    final borderWidth = isSelected ? 3.0 : 1.5;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Cor',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StrokeWidthSelector extends StatelessWidget {
  const _StrokeWidthSelector({
    required this.selected,
    required this.isTablet,
    required this.onSelected,
  });

  final StrokeWidthLevel selected;
  final bool isTablet;
  final ValueChanged<StrokeWidthLevel> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: StrokeWidthLevel.values.map((level) {
        final isSelected = level == selected;
        final dotSize = level.indicatorSize(isTablet: isTablet);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Semantics(
            button: true,
            selected: isSelected,
            label: switch (level) {
              StrokeWidthLevel.thin => 'Traço fino',
              StrokeWidthLevel.medium => 'Traço médio',
              StrokeWidthLevel.thick => 'Traço grosso',
            },
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onSelected(level),
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1565C0)
                          : const Color(0xFFBDBDBD),
                      width: isSelected ? 3 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: const BoxDecoration(
                        color: Color(0xFF424242),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Desfazer',
      child: Material(
        color: enabled ? const Color(0xFF1565C0) : const Color(0xFFBDBDBD),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: Icon(
              Icons.undo,
              color: enabled ? Colors.white : const Color(0xFF757575),
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Apagar tudo',
      child: Material(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(
            height: 44,
            width: double.infinity,
            child: Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _PinButton extends StatelessWidget {
  const _PinButton({required this.pinned, required this.onTap});

  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: pinned ? 'Liberar tela' : 'Fixar tela',
      child: Material(
        color: pinned ? const Color(0xFF1565C0) : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: Icon(
              pinned ? Icons.lock : Icons.lock_open,
              color: pinned ? Colors.white : const Color(0xFF424242),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
