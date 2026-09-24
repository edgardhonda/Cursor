# Garras

Jogo Flutter para **Android** e **Android Go** (celular e tablet): aviões coloridos voam pelo céu; toque no buraco da mesma cor para a garra capturar o avião e fazê-lo cair no buraco.

## Como jogar

1. Aviões de várias cores atravessam a tela.
2. Toque no **buraco** da cor correspondente.
3. A garra sobe, agarra o avião e o puxa para o buraco.
4. Novos aviões aparecem continuamente.
5. Acerte em sequência para aumentar o **combo**.

## Sons

- Voo do avião (whoosh)
- Garra atacando (snap)
- Queda no buraco (fall + chirp)
- Erro / miss

## Rodar

```bash
flutter pub get
flutter run
```

Gerar SFX de novo:

```bash
python tool/generate_sfx.py
```
