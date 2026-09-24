# Luta

Jogo Android nativo de luta 2D **arcade**. Um stickman ninja pequeno responde na hora a toques e swipes: jab, chute, atravessar a arena e saltos acrobáticos contra vários inimigos.

## Controles

A tela inteira é o controle. Sem botões.

| Gesto | Ação |
| --- | --- |
| Toque | Jab / chute (alterna sozinho) |
| Toques seguidos | Combo jab-chute |
| Swipe → ou ← | Golpe longo + avanço (atravessa inimigos) |
| Swipe ↑ | Salto + golpe ascendente |
| Swipe ↗ ↖ | Salto direcional + ataque |
| Swipe ↘ ↙ ou ↓ | Mergulho / evasão |

O swipe dispara assim que o dedo anda o suficiente — não espera soltar.

## Feel

Personagens com ~13% da altura da tela, câmera afastada, 5–10 inimigos, hit-stop curto, combo, cancelamento de animação. Tudo ajustável em `CombatConfig`.

```
Toque → jab
Toque → chute
Swipe → → atravessa
Swipe ↑ → salto
Swipe ↗ → salto para frente
```

## Rodar

Abra no Android Studio ou:

```bash
gradlew assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`
