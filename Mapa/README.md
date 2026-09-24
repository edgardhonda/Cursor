# Mapa

Jogo Flutter para **Android** e **Android Go** (celular e tablet): programe o pirata com setas para chegar ao tesouro num mapa 5×5.

## Como jogar

1. O pirata começa na célula inferior central.
2. O **X** na linha de cima marca o tesouro.
3. Obstáculos (barril, espada, polvo, caveira, palmeira) bloqueiam o caminho — sempre há rota livre.
4. Use as setas para montar a sequência (aparece abaixo).
5. Toque em **Ir!** — o pirata destaca o comando e depois anda.
6. Se não bater, pode dar novos comandos e **Ir!** de novo a partir da posição atual.
7. Bater na borda ou obstáculo: batida + pirata desmaiado/amassado.
8. Chegar ao X: música de vitória + baú de jóias.
9. **Reiniciar!** gera um mapa novo e volta o pirata ao início.

## Rodar

```bash
flutter pub get
flutter run
```
