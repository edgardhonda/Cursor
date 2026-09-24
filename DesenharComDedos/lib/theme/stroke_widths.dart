/// Três espessuras de traço — o nível médio é o padrão original do app.
enum StrokeWidthLevel { thin, medium, thick }

extension StrokeWidthLevelX on StrokeWidthLevel {
  double widthFor({required bool isTablet}) {
    if (isTablet) {
      return switch (this) {
        StrokeWidthLevel.thin => 8,
        StrokeWidthLevel.medium => 14,
        StrokeWidthLevel.thick => 22,
      };
    }
    return switch (this) {
      StrokeWidthLevel.thin => 6,
      StrokeWidthLevel.medium => 10,
      StrokeWidthLevel.thick => 16,
    };
  }

  /// Tamanho visual do indicador na barra lateral.
  double indicatorSize({required bool isTablet}) {
    if (isTablet) {
      return switch (this) {
        StrokeWidthLevel.thin => 6,
        StrokeWidthLevel.medium => 10,
        StrokeWidthLevel.thick => 16,
      };
    }
    return switch (this) {
      StrokeWidthLevel.thin => 5,
      StrokeWidthLevel.medium => 8,
      StrokeWidthLevel.thick => 12,
    };
  }
}
