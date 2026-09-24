# Desenhar com Dedos

App Android simples para desenhar com os dedos — pensado para quem precisa de interface mínima e alvos grandes.

## Características

- **Só desenhar** — sem menus, zoom, arrastar ou redimensionar
- **Vários dedos ao mesmo tempo** — cada toque traça independentemente
- **Paleta lateral** com 10 cores (preto, branco, vermelho, laranja, amarelo, verde, azul, roxo, marrom, rosa)
- **Botão apagar tudo** (ícone de lixeira) abaixo das cores
- **Celular e tablet** — paleta mais larga em telas grandes
- **Android Go** — app leve, sem dependências extras, `minSdk 21`

## Executar

```powershell
cd DesenharComDedos
flutter pub get
flutter run
```

## Gerar APK

```powershell
flutter build apk --release --split-per-abi
```

APKs em `build/app/outputs/flutter-apk/`.

## Estrutura

```
lib/
  main.dart
  screens/drawing_screen.dart
  widgets/drawing_canvas.dart   # multitouch com Listener
  widgets/color_palette.dart
  models/stroke.dart
  theme/app_colors.dart
```

## Uso

1. Toque numa cor na barra lateral
2. Desenhe na área branca com um ou vários dedos
3. Toque no ícone azul de **desfazer** para remover o último traço
4. Toque no ícone vermelho de lixeira para apagar tudo

A cor **branca** funciona como “borracha” sobre desenhos coloridos.
