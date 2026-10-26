# Jornada pessoal e melhorias das abas

## Início

“Seu próximo passo” prioriza a aula em andamento aberta mais recentemente.
Sem uma aula em andamento, oferece registrar hábitos pendentes, abrir o desafio
ativo ou explorar o catálogo. A ação da aula abre a próxima ainda não concluída.

O resumo semanal compara de segunda-feira até hoje com os mesmos dias da semana
anterior, usando a seleção atual de hábitos. Mostra hábitos registrados, novas
conclusões de aulas neste aparelho e registros diários em desafios. Dois desafios
registrados no mesmo dia contam como dois registros, não dois dias diferentes.
Falhas de uma fonte são exibidas como indisponibilidade, sem convertê-las em zero.

As datas das aulas são registradas localmente na primeira conclusão conhecida.
Conclusões anteriores ao recurso e conclusões recebidas de outro aparelho sem
data não são atribuídas artificialmente à semana atual. As datas locais se
mantêm ao sincronizar o conjunto de conclusões com o servidor.

## Anotações

As aulas têm “Minhas anotações”, com salvamento explícito, limite de 6000
caracteres e aviso antes de descartar alterações. As anotações ficam no aparelho,
separadas por conta, programa e aula. Não são publicadas nem sincronizadas.
Visitantes usam um espaço próprio. Limpar os dados do navegador/app também
remove essas anotações; mudar de aparelho não transfere o conteúdo local.

## Comunidade

Foram acrescentados Dúvidas, Conquistas e Recomendações aos temas já existentes.
Os filtros e o formulário usam a mesma lista de tópicos. A aba Conquistas inclui
publicações categorizadas assim e as que já tinham um selo/tag de conquista.
A pergunta semanal já existente continua disponível.

Aplicar `supabase/migrations/20261026000700_community_topics.sql` antes de
publicar nos novos tópicos. Essa migration preserva os temas antigos.

## Objetivo pessoal

O Perfil permite definir um objetivo, seu próximo passo e registrar pequenos
avanços. É necessário entrar na conta. O objetivo começa privado; compartilhar
exige ativação explícita e salvamento. O compartilhamento mostra apenas título
e próximo passo, respeitando perfil privado e bloqueios. Os avanços são sempre
privados, inclusive quando o objetivo é compartilhado.

Editar o objetivo mantém os registros anteriores; cada avanço preserva o título
que o objetivo tinha quando foi registrado. A tela mostra os últimos 30 avanços,
sem apagar os registros mais antigos do banco.

Aplicar `supabase/migrations/20261026000800_personal_goals.sql` para habilitar.
O banco restringe a leitura e a escrita privadas ao titular. O perfil de outro
membro usa uma função pública que entrega somente os campos permitidos.

## Destaque manual

Em Admin → Gerenciar programas e aulas → Editar programa, ativar “Destacar uma
aula”, escolher a aula, uma apresentação opcional e a data final, depois salvar.
O programa também precisa estar publicado. “Seleção da semana” aparece no Início
e em Conteúdo, com a prévia do vídeo/podcast quando houver e acesso direto à aula.

Quando existem vários destaques válidos, aparece o que tem a data final mais
distante. Um destaque expirado deixa de aparecer; a seleção é revisada ao
atualizar a tela e o cartão verifica sua validade a cada minuto. Não há busca,
troca automática de links, IA ou integração com novos provedores pagos.

Aplicar `supabase/migrations/20261026000900_manual_content_highlights.sql` antes
de usar os campos novos no editor. A migration amplia a tabela do catálogo e
reutiliza as permissões administrativas existentes.

## Ordem de ativação e testes

Depois das migrations anteriores do projeto, aplicar `007`, `008` e `009`, nessa
ordem. As migrations de conteúdo `001` a `004` continuam necessárias. O arquivo
`006` é somente para remover a antiga rotação automática, se ela foi instalada.
Nenhuma migration é aplicada automaticamente pelo Flutter.

```powershell
flutter test test/journey_features_test.dart test/program_learning_test.dart
npx --offline --yes deno test --cached-only --allow-read --allow-env supabase/tests/journey_privacy_test.ts
```

Os testes de banco usam PostgreSQL embarcado e não conectam ao projeto Supabase.
Após aplicar as migrations, conferir no projeto real o compartilhamento com uma
segunda conta, os novos tópicos e a publicação de um destaque.
