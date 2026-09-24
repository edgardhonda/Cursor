enum ObstacleKind {
  hole,
  campfire,
  river,
  wall,
  rock,
  quicksand,
  ice,
  spikes,
  vegetation,
  tree,
  brokenBridge,
  hurricane,
  monster,
  animal,
  swarm,
  carnivorousPlant,
  spiderWeb,
  pit,
  lava,
  mud,
  canyon,
  fence,
  boulder,
  thornBush,
  fallenLog,
  mudSlide,
  snowDrift,
  electricWire,
  tornado,
  bear,
  snake,
  beehive,
  giantMushroom,
  bambooGrove,
}

enum ResourceKind {
  board,
  rope,
  water,
  wind,
  stone,
  ladder,
  fire,
  pickaxe,
  axe,
  scissors,
  bomb,
}

enum ResolveAction { crossOver, extinguish, climb, destroy, scare }

enum ExplorerPhase {
  walking,
  choosing,
  showcasing,
  resolving,
  sad,
  celebrating,
  scrolling,
}

class ChoiceOption {
  const ChoiceOption({
    required this.resource,
    required this.correct,
  });

  final ResourceKind resource;
  final bool correct;
}

class PlacedObstacle {
  PlacedObstacle({
    required this.kind,
    required this.x,
  });

  final ObstacleKind kind;
  final double x; // 0..1 ao longo do trecho
  bool cleared = false;
  /// Recurso usado para resolver (ex.: tábua permanece no cenário).
  ResourceKind? resolveResource;
  /// Fuga após "Espanta" (0 = no lugar, 1 = fora da tela).
  double fleeT = 0;
  bool fleeing = false;
}

class ObstacleSpec {
  const ObstacleSpec({
    required this.kind,
    required this.label,
    required this.validResources,
    required this.action,
    required this.actionLabel,
  });

  final ObstacleKind kind;
  final String label;
  final List<ResourceKind> validResources;
  final ResolveAction action;
  final String actionLabel;
}

const Map<ObstacleKind, ObstacleSpec> obstacleCatalog = {
  ObstacleKind.hole: ObstacleSpec(
    kind: ObstacleKind.hole,
    label: 'Buraco',
    validResources: [ResourceKind.board, ResourceKind.rope],
    action: ResolveAction.crossOver,
    actionLabel: 'Atravessa por cima',
  ),
  ObstacleKind.campfire: ObstacleSpec(
    kind: ObstacleKind.campfire,
    label: 'Fogueira',
    validResources: [ResourceKind.water, ResourceKind.wind],
    action: ResolveAction.extinguish,
    actionLabel: 'Apaga',
  ),
  ObstacleKind.river: ObstacleSpec(
    kind: ObstacleKind.river,
    label: 'Rio',
    validResources: [ResourceKind.board, ResourceKind.rope],
    action: ResolveAction.crossOver,
    actionLabel: 'Atravessa por cima',
  ),
  ObstacleKind.wall: ObstacleSpec(
    kind: ObstacleKind.wall,
    label: 'Muro',
    validResources: [ResourceKind.ladder, ResourceKind.rope],
    action: ResolveAction.climb,
    actionLabel: 'Sobe e passa',
  ),
  ObstacleKind.rock: ObstacleSpec(
    kind: ObstacleKind.rock,
    label: 'Pedra bloqueando',
    validResources: [ResourceKind.bomb, ResourceKind.pickaxe],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.quicksand: ObstacleSpec(
    kind: ObstacleKind.quicksand,
    label: 'Areia movediça',
    validResources: [ResourceKind.board, ResourceKind.rope],
    action: ResolveAction.crossOver,
    actionLabel: 'Atravessa por cima',
  ),
  ObstacleKind.ice: ObstacleSpec(
    kind: ObstacleKind.ice,
    label: 'Gelo bloqueando',
    validResources: [ResourceKind.fire, ResourceKind.pickaxe, ResourceKind.bomb],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.spikes: ObstacleSpec(
    kind: ObstacleKind.spikes,
    label: 'Espinhos',
    validResources: [ResourceKind.fire, ResourceKind.axe, ResourceKind.scissors],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.vegetation: ObstacleSpec(
    kind: ObstacleKind.vegetation,
    label: 'Vegetação densa',
    validResources: [ResourceKind.scissors, ResourceKind.axe, ResourceKind.fire],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.tree: ObstacleSpec(
    kind: ObstacleKind.tree,
    label: 'Árvore bloqueando',
    validResources: [ResourceKind.axe, ResourceKind.fire],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.brokenBridge: ObstacleSpec(
    kind: ObstacleKind.brokenBridge,
    label: 'Ponte quebrada',
    validResources: [ResourceKind.board, ResourceKind.rope],
    action: ResolveAction.crossOver,
    actionLabel: 'Atravessa por cima',
  ),
  ObstacleKind.hurricane: ObstacleSpec(
    kind: ObstacleKind.hurricane,
    label: 'Furacão',
    validResources: [ResourceKind.wind, ResourceKind.fire, ResourceKind.bomb],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.monster: ObstacleSpec(
    kind: ObstacleKind.monster,
    label: 'Monstro',
    validResources: [ResourceKind.fire, ResourceKind.water],
    action: ResolveAction.scare,
    actionLabel: 'Espanta',
  ),
  ObstacleKind.animal: ObstacleSpec(
    kind: ObstacleKind.animal,
    label: 'Animal agressivo',
    validResources: [ResourceKind.fire, ResourceKind.water],
    action: ResolveAction.scare,
    actionLabel: 'Espanta',
  ),
  ObstacleKind.swarm: ObstacleSpec(
    kind: ObstacleKind.swarm,
    label: 'Enxame de insetos',
    validResources: [ResourceKind.fire, ResourceKind.wind, ResourceKind.water],
    action: ResolveAction.scare,
    actionLabel: 'Espanta',
  ),
  ObstacleKind.carnivorousPlant: ObstacleSpec(
    kind: ObstacleKind.carnivorousPlant,
    label: 'Planta carnívora',
    validResources: [ResourceKind.fire, ResourceKind.axe, ResourceKind.scissors],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.spiderWeb: ObstacleSpec(
    kind: ObstacleKind.spiderWeb,
    label: 'Teia de aranha',
    validResources: [ResourceKind.fire, ResourceKind.scissors, ResourceKind.axe],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.pit: ObstacleSpec(
    kind: ObstacleKind.pit,
    label: 'Poço fundo',
    validResources: [ResourceKind.board, ResourceKind.rope],
    action: ResolveAction.crossOver,
    actionLabel: 'Atravessa por cima',
  ),
  ObstacleKind.lava: ObstacleSpec(
    kind: ObstacleKind.lava,
    label: 'Lava',
    validResources: [ResourceKind.stone, ResourceKind.board],
    action: ResolveAction.crossOver,
    actionLabel: 'Atravessa por cima',
  ),
  ObstacleKind.mud: ObstacleSpec(
    kind: ObstacleKind.mud,
    label: 'Lama profunda',
    validResources: [ResourceKind.board, ResourceKind.rope],
    action: ResolveAction.crossOver,
    actionLabel: 'Atravessa por cima',
  ),
  ObstacleKind.canyon: ObstacleSpec(
    kind: ObstacleKind.canyon,
    label: 'Desfiladeiro',
    validResources: [ResourceKind.rope, ResourceKind.board],
    action: ResolveAction.crossOver,
    actionLabel: 'Atravessa por cima',
  ),
  ObstacleKind.fence: ObstacleSpec(
    kind: ObstacleKind.fence,
    label: 'Cerca alta',
    validResources: [ResourceKind.ladder, ResourceKind.rope],
    action: ResolveAction.climb,
    actionLabel: 'Sobe e passa',
  ),
  ObstacleKind.boulder: ObstacleSpec(
    kind: ObstacleKind.boulder,
    label: 'Pedregulho',
    validResources: [ResourceKind.bomb, ResourceKind.pickaxe],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.thornBush: ObstacleSpec(
    kind: ObstacleKind.thornBush,
    label: 'Arbusto espinhoso',
    validResources: [ResourceKind.scissors, ResourceKind.fire, ResourceKind.axe],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.fallenLog: ObstacleSpec(
    kind: ObstacleKind.fallenLog,
    label: 'Tronco caído',
    validResources: [ResourceKind.axe, ResourceKind.fire],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.mudSlide: ObstacleSpec(
    kind: ObstacleKind.mudSlide,
    label: 'Deslizamento de lama',
    validResources: [ResourceKind.board, ResourceKind.stone],
    action: ResolveAction.crossOver,
    actionLabel: 'Atravessa por cima',
  ),
  ObstacleKind.snowDrift: ObstacleSpec(
    kind: ObstacleKind.snowDrift,
    label: 'Monte de neve',
    validResources: [ResourceKind.fire, ResourceKind.pickaxe, ResourceKind.bomb],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.electricWire: ObstacleSpec(
    kind: ObstacleKind.electricWire,
    label: 'Fios caídos',
    validResources: [ResourceKind.scissors, ResourceKind.bomb],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.tornado: ObstacleSpec(
    kind: ObstacleKind.tornado,
    label: 'Tornado',
    validResources: [ResourceKind.wind, ResourceKind.bomb, ResourceKind.fire],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.bear: ObstacleSpec(
    kind: ObstacleKind.bear,
    label: 'Urso',
    validResources: [ResourceKind.fire, ResourceKind.water],
    action: ResolveAction.scare,
    actionLabel: 'Espanta',
  ),
  ObstacleKind.snake: ObstacleSpec(
    kind: ObstacleKind.snake,
    label: 'Cobra venenosa',
    validResources: [ResourceKind.fire, ResourceKind.water],
    action: ResolveAction.scare,
    actionLabel: 'Espanta',
  ),
  ObstacleKind.beehive: ObstacleSpec(
    kind: ObstacleKind.beehive,
    label: 'Colmeia de abelhas',
    validResources: [ResourceKind.fire, ResourceKind.wind, ResourceKind.water],
    action: ResolveAction.scare,
    actionLabel: 'Espanta',
  ),
  ObstacleKind.giantMushroom: ObstacleSpec(
    kind: ObstacleKind.giantMushroom,
    label: 'Cogumelo gigante',
    validResources: [ResourceKind.fire, ResourceKind.axe, ResourceKind.scissors],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
  ObstacleKind.bambooGrove: ObstacleSpec(
    kind: ObstacleKind.bambooGrove,
    label: 'Bambuzal',
    validResources: [ResourceKind.axe, ResourceKind.scissors, ResourceKind.fire],
    action: ResolveAction.destroy,
    actionLabel: 'Destrói',
  ),
};

extension ResourceKindX on ResourceKind {
  String get label => switch (this) {
        ResourceKind.board => 'Tábua',
        ResourceKind.rope => 'Corda',
        ResourceKind.water => 'Água',
        ResourceKind.wind => 'Vento',
        ResourceKind.stone => 'Pedra',
        ResourceKind.ladder => 'Escada',
        ResourceKind.fire => 'Fogo',
        ResourceKind.pickaxe => 'Picareta',
        ResourceKind.axe => 'Machado',
        ResourceKind.scissors => 'Tesoura',
        ResourceKind.bomb => 'Bomba',
      };

  String get hint => switch (this) {
        ResourceKind.board => 'Uma tábua firme para atravessar',
        ResourceKind.rope => 'Uma corda resistente',
        ResourceKind.water => 'Um balde d’água',
        ResourceKind.wind => 'Uma rajada de vento',
        ResourceKind.stone => 'Pedras para pisar',
        ResourceKind.ladder => 'Uma escada para subir',
        ResourceKind.fire => 'Uma tocha flamejante',
        ResourceKind.pickaxe => 'Uma picareta pesada',
        ResourceKind.axe => 'Um machado afiado',
        ResourceKind.scissors => 'Uma tesoura grande',
        ResourceKind.bomb => 'Uma bomba explosiva',
      };
}

const double walkSpeed = 0.11;
const double showcaseSeconds = 0.85;
const double resolveSeconds = 1.15;
const double fleeSeconds = 1.1;
const double sadSeconds = 1.0;
const double cheerSeconds = 1.6;
const double scrollSeconds = 0.85;
const int minObstaclesPerSegment = 2;
const int maxObstaclesPerSegment = 4;
