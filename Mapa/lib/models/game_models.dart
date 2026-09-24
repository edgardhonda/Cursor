enum MoveCommand { up, down, left, right }

enum CellKind { empty, obstacleBarrel, obstacleSword, obstacleOctopus, obstacleSkull, obstaclePalm }

enum PiratePhase { ready, walking, fainted, smashed, celebrating }

enum GamePhase { programming, running, lost, won }

enum CrashKind { none, obstacle, wall }

enum RunStepPhase { waiting, previewing }

class PathMark {
  const PathMark({required this.cell, required this.command});

  final GridPos cell;
  final MoveCommand command;
}

class GridPos {
  const GridPos(this.row, this.col);

  final int row;
  final int col;

  GridPos moved(MoveCommand cmd) => switch (cmd) {
        MoveCommand.up => GridPos(row - 1, col),
        MoveCommand.down => GridPos(row + 1, col),
        MoveCommand.left => GridPos(row, col - 1),
        MoveCommand.right => GridPos(row, col + 1),
      };

  bool get inBounds => row >= 0 && row < gridSize && col >= 0 && col < gridSize;

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

const int gridSize = 5;
const int pirateStartRow = 4;
const int pirateStartCol = 2;
const double stepSeconds = 0.45;
const double commandPreviewSeconds = 0.65;
const int minObstacles = 3;
const int maxObstacles = 6;

extension MoveCommandX on MoveCommand {
  String get label => switch (this) {
        MoveCommand.up => '↑',
        MoveCommand.down => '↓',
        MoveCommand.left => '←',
        MoveCommand.right => '→',
      };

  String get namePt => switch (this) {
        MoveCommand.up => 'Cima',
        MoveCommand.down => 'Baixo',
        MoveCommand.left => 'Esquerda',
        MoveCommand.right => 'Direita',
      };
}

extension CellKindX on CellKind {
  bool get isObstacle => this != CellKind.empty;
}
