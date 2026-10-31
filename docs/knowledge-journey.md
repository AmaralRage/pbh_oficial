# Jornadas de desafios

A aba Desafios permite alternar entre **Original PBH** e **Conhecimento**, tanto nos desafios quanto nas conquistas. Cada jornada tem seu progresso, pontuação e troféu final: platina na Original e rubi no Conhecimento.

## Jornada Original PBH

Preserva os 57 desafios originais, os registros diários e a Platina PBH. A lista de requisitos é fixa: os desafios novos não entram na exigência dessa platina. A moldura de platina também continua disponível para quem concluiu a coleção original.

## Jornada do Conhecimento

| Desafio | Duração | Troféu |
|---|---|---|
| Leitor em construção | 7 dias de leitura | Bronze |
| Caderno de descobertas | 7 dias de anotações | Bronze |
| Estudo com intenção | 14 dias de estudo | Prata |
| Aprender para explicar | 14 dias de explicação e revisão | Prata |
| Conhecimento em ação | 21 dias aplicando o aprendizado | Ouro |

Completar os cinco libera o **Rubi do Conhecimento**, com arte e animação próprias. A jornada usa a capa `assets/images/capaJornada.png`, que pode ser ampliada ao tocar. O rubi aparece ao lado da Platina PBH no perfil quando conquistado. É possível selecionar até três outras conquistas para essa vitrine. O ID interno `knowledge_platinum` foi mantido para preservar progresso e recompensas existentes; não é necessário refazer os desafios.

As sessões são registradas pelo próprio usuário, no mesmo fluxo dos desafios existentes. Os textos orientam o que fazer antes de marcar cada dia; não há verificação automática de leitura ou estudo. A jornada não exige pagamentos ou serviços externos.

## Ativação

Execute uma vez no SQL Editor do Supabase o arquivo **`supabase/migrations/20261028000200_knowledge_journey.sql`**, depois das migrações anteriores. Ele cria o catálogo público de jornadas, fixa seus membros, adiciona cinco desafios e atualiza a leitura pública do perfil para preservar a moldura de platina original. As tabelas de progresso existentes continuam sendo usadas.

O aplicativo precisa ser atualizado para apresentar as jornadas. Os desafios novos só podem ser iniciados depois da instalação dessa migração. A relação de requisitos também está em `lib/models/challenge_journey.dart`; alterações futuras precisam manter os IDs sincronizados com o banco.
