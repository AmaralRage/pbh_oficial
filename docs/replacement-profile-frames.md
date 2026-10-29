# Molduras comuns atualizadas

## Coroa cósmica do fundador

`moldura_coroa_cosmica_pbh.html` foi adaptada em `cosmic_crown_frame_art.dart`:
coroa flutuante, aro violeta, duas órbitas opostas, gemas e estrelas. O ID `crown`
e o requisito de fundador são preservados. A intensidade controla o brilho.
O desenho ocupa 168 px ao redor do avatar e mantém seu centro transparente;
pausa e movimento reduzido seguem os controles existentes. Não exige SQL novo.

## Modelos de eventos

As artes de `molduras_pbh_eventos_sem_chuva.html` substituem apenas as molduras
`rain`, `halloween`, `christmas` e `new_year`. As opções mantêm seus nomes atuais,
IDs, intensidade e permissões. As capas não são alteradas.

- Chuva: metal azul-gelo, reflexos orbitais, gotas decorativas fixas e clarões no aro, sem chuva caindo.
- Halloween: metal laranja-violeta, coroa, névoa, morcegos e pequenas chamas.
- Natal: aro vermelho/dourado/verde, luzinhas e flocos.
- Ano Novo: aro claro, estrelas, confetes e partículas de fogos.

O Canvas nativo em `event_profile_frame_art.dart` usa um espaço de 132 px e uma
área central transparente para proteger a foto. Os testes verificam fases e
intensidades diferentes. Não é necessária migração SQL para esta substituição.

As quatro artes exibidas por `molduras_pbh_quatro_novas_chamas.html` substituem opções existentes. O arquivo também contém as quatro molduras lendárias antigas como dados, mas a prévia usa somente `specs.slice(4)`; elas não foram substituídas.

| ID preservado | Opção | Nova animação |
|---|---|---|
| `orbit` | Órbita de luz | Dois satélites, trilhas e aro azul-violeta |
| `pulse` | Pulso suave | Halos perolados alternando a respiração |
| `sparks` | Chamas Vivas, anteriormente Faíscas | Línguas de fogo e brasas ao redor do aro |
| `double` | Anéis gêmeos | Duas elipses girando em sentidos opostos |

Os requisitos e as seleções salvas são mantidos. Nenhuma nova migração é necessária. As molduras exclusivas de platina continuam usando seus IDs e requisitos próprios.

O desenho usa `animated_profile_frame_art.dart` no Canvas do Flutter, com intensidade ajustável e o mesmo controle existente de pausa, visibilidade e movimento reduzido. A moldura tem 120 px em torno do avatar de 96 px; Chamas Vivas usa 132 px para acomodar o fogo. O centro do avatar permanece na posição original e sua imagem não é alterada. O espaço abaixo do avatar cresce para não cortar a decoração.

O teste `legendary_frame_art_test.dart` verifica a transparência do centro nas quatro molduras, em diferentes fases e intensidades. A prévia estática de desenvolvimento pode ser gerada pelos testes locais; não é um recurso do aplicativo.
