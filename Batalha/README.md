# Batalha

Dois exércitos em cantos opostos. Cada lado tem 15 de custo para montar a tropa; depois **Lutar!** até um lado ser destruído.

Feito para Android e Android Go (telefone e tablet). Impeller desligado no Android.

## Unidades e custos

Os custos cabem no orçamento 15 de forma que nenhuma formação seja um trunfo automático:

| Unidade   | Tipo     | Tam. | Atq | Def | Vel | Raio | Freq/2s | Visão | Custo |
|-----------|----------|------|-----|-----|-----|------|---------|-------|-------|
| Cachorro  | melee    | 1    | 1   | 5   | 7   | —    | 7       | 10    | **1** |
| Soldado   | melee    | 2    | 3   | 10  | 5   | —    | 5       | 10    | **2** |
| Cavaleiro | melee    | 2    | 5   | 10  | 4   | —    | 5       | 7     | **4** |
| Gigante   | melee    | 4    | 10  | 20  | 2   | —    | 1       | 5     | **5** |
| Arqueiro  | distância| 2    | 2   | 5   | 3   | 10   | 3       | 20    | **3** |
| Canhão    | distância| 4    | 5   | 10  | 3   | 10   | 1       | 20    | **7** |

Máximo no orçamento: 15 cães, 7 soldados, 3 cavaleiros, 3 gigantes, 5 arqueiros, 2 canhões.

- Enxame de cães é barato, mas cavaleiro, gigante e canhão matam um cão por golpe.
- Só 3 cavaleiros cabem, então eles não varrem 15 cães sozinhos.
- 2 canhões deixam só 1 de custo: artilharia lenta, sem terceira peça.
- Gigante e arqueiro baixaram de custo com o fogo mais lento; soldados e cavaleiros ainda furam o muro.

## Como jogar

1. Toque na paleta de cada canto para posicionar unidades (debita o custo).
2. Toque numa unidade já colocada para removê-la (devolve o custo).
3. **Lutar!** começa o combate quando os dois lados têm pelo menos uma unidade.
4. **Reiniciar** volta à montagem.

## Rodar

```bash
flutter test
flutter run
```
