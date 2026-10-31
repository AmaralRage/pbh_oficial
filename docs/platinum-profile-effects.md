# Efeitos exclusivos das jornadas

No editor do perfil, abra **Foto → Animação da moldura → Jornadas** ou **Capa → Animação sobre a capa → Jornadas**. As opções são agrupadas em comuns disponíveis, recompensas de jornadas e exclusivas; os requisitos continuam visíveis nas recompensas bloqueadas.

| Requisito | Moldura | Capa |
|---|---|---|
| Platina PBH: 57 desafios originais | Guardião de Platina: cristais glaciais; Juramento de Ferro: metal negro, fissuras e brasas | Forja da Disciplina: espada, brasas e faíscas; Trono do Inabalável: trono e chamas violetas |
| Rubi do Conhecimento: cinco desafios de Conhecimento | Selo Arcano: obsidiana, runas e círculos místicos | Biblioteca dos Sábios: estantes, velas e páginas flutuantes |
| Platina PBH e Rubi do Conhecimento | Coroa do Legado: ouro envelhecido, coroa e louros pulsantes | Observatório Eterno: cúpula, constelações, órbitas e meteoros |

Todos os efeitos têm controle de intensidade, respeitam movimento reduzido e são sobrepostos à imagem, GIF ou arte HTML da capa. O fundador segue a regra existente de acesso às recompensas.

Para ativar a validação nos perfis públicos, execute no SQL Editor **`supabase/migrations/20261028000500_legendary_platinum_frames.sql`**, depois da migração da Jornada do Conhecimento. O servidor verifica a conclusão dos membros de cada jornada. Alterar manualmente os IDs dos efeitos nos metadados não concede acesso.

O novo arquivo não precisa ser reaplicado quando o usuário conquista uma platina: a liberação é calculada automaticamente ao atualizar o perfil/editor. Os efeitos aparecem bloqueados com indicação de requisito até a conquista.

As quatro capas foram adaptadas do arquivo fornecido `capas_animadas_pbh_edicao_lendaria.html`. A arquitetura é desenhada uma vez e reaproveitada; partículas e efeitos usam o relógio do Flutter. O fundo opaco da prévia HTML não é aplicado por cima da foto enviada. Os IDs dos três efeitos anteriores foram preservados; seleções antigas passam a usar a nova arte. As molduras foram adaptadas de molduras_animadas_pbh.html. O espaço da sobreposição aumenta para 120 px, preservando o centro da foto e evitando o corte dos cristais e louros.
