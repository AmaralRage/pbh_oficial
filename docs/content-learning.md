# Área de conteúdo

As melhorias de resumo semanal, anotações, objetivos pessoais e destaques
manuais estão descritas em [Jornada pessoal](journey-improvements.md).

A biblioteca contém cinco programas, dez módulos e vinte aulas de
texto com práticas. As quantidades nos cartões vêm do material cadastrado. Duas
semanas é um ritmo sugerido, sem bloqueio de aulas por data ou ordem.

## Banco de dados

Aplicar, nesta ordem, no mesmo projeto Supabase usado pelo app:

1. `supabase/migrations/20261026000100_content_learning.sql`
2. `supabase/migrations/20261026000200_content_initial_catalog.sql`
3. `supabase/migrations/20261026000300_content_related_media.sql`
4. `supabase/migrations/20261026000400_content_nihilism.sql`

Os vídeos são escolhidos e atualizados manualmente no editor de aulas. Não há
busca automática nem integração com APIs de inteligência artificial. Para os
links e prévias existentes, não é necessária uma chave do YouTube ou da OpenAI.

Se a antiga rotação automática chegou a ser instalada no Supabase, aplicar
`20261026000600_remove_content_video_rotation.sql`. Esse arquivo remove apenas
o agendamento, as funções, as tabelas auxiliares e os segredos do Vault usados
pela rotação; preserva os programas, vídeos publicados e progresso dos alunos.
Se publicou a Edge Function `rotate-content-videos`, excluí-la também no painel
do Supabase. Os Secrets exclusivos dessa função podem ser removidos no painel.

A quarta migration acrescenta **Niilismo: riscos e reconstrução de sentido** com
dois módulos e quatro aulas. Se as anteriores já estiverem aplicadas, executar
somente a quarta. Ela não sobrescreve um programa de mesmo ID já editado.

Se as duas primeiras já estiverem aplicadas, executar somente a terceira para
acrescentar vídeos e podcasts às aulas existentes. Ela preserva IDs, textos,
progresso e referências de mídia que já tenham sido cadastradas pelo editor.

As migrations anteriores do projeto devem estar aplicadas, incluindo `profiles`
e a função `public.is_admin()`. A primeira cria o catálogo, as políticas de acesso
e a função de sincronização; a segunda insere o material inicial com IDs estáveis.
O seed usa `on conflict do nothing` para não sobrescrever edições existentes.

Nenhuma migration é aplicada automaticamente pelo aplicativo. Sem as novas
tabelas, as aulas embarcadas e o progresso local continuam utilizáveis; a tela
informa que catálogo/progresso são os disponíveis neste aparelho. O editor e a
sincronização entre aparelhos dependem das migrations.

## Administração

Uma conta administradora pode acessar **Admin → Gerenciar programas e aulas**
ou o botão de edição no cabeçalho de Conteúdo. O editor permite criar e editar
programas, módulos e aulas, ordenar o material, vincular hábitos, visualizar uma
prévia e publicar/despublicar. A prévia não registra conclusão ou altera hábitos.

Cada programa informa tema, nível, apresentação, descrição, objetivos e ritmo
sugerido. Cada aula informa título, texto, prática, duração estimada e hábito
opcional. Para publicar, todos os módulos precisam conter aulas preenchidas.

Mantenha os IDs de aulas já publicadas. O editor preserva esses IDs ao editar e
reordenar. Remover uma aula não remove seu histórico de conclusão, mas ela deixa
de contar no progresso atual. Um novo módulo ou aula recebe um novo ID.

Somente administradores podem escrever no catálogo. Visitantes e membros leem
apenas programas publicados; rascunhos não são disponibilizados pelo banco.
Sem conexão, o app usa a última versão pública armazenada ou a versão embarcada,
que pode estar desatualizada até a próxima atualização online.

## Progresso e recomendações

Favoritos, início, última abertura e conclusões são armazenados por conta. Para
membros, alterações são gravadas localmente antes da tentativa de sincronização.
Uma falha mantém a alteração pendente para nova tentativa ao abrir/atualizar o
conteúdo. O banco combina conclusões de aparelhos diferentes sem apagar aulas já
concluídas; favoritos usam a alteração mais recente. O progresso é privado para
o titular da conta. Visitantes usam somente armazenamento local.

Preferências antigas de programas não identificavam uma conta. Elas são lidas
apenas no modo visitante para evitar atribuí-las a outro usuário do aparelho.
O progresso de visitante não é importado automaticamente para uma conta.

Os interesses são preferências locais separadas por conta. Recomendações
priorizam programas em andamento, depois temas escolhidos e favoritos, deixando
programas concluídos por último. O bloco de retomada ordena pela última abertura.
A busca inclui títulos de aulas; filtros incluem tema, nível, salvos e concluídos.

Vincular uma prática à rotina adiciona um hábito existente, sem criar novos tipos
de hábito ou marcá-lo automaticamente como concluído. Os lembretes existentes
são atualizados; falhas de atualização são informadas ao usuário.

## Vídeos e podcasts

Ao abrir uma aula, uma referência opcional apresenta capa em proporção 16:9,
título, autor, resumo curto e botões para assistir ou ouvir na plataforma de
origem. A prévia é uma imagem e um resumo, sem reprodução automática ou trecho
de vídeo hospedado no app. Uma falha na capa exibe um ícone; uma falha ao abrir
oferece copiar o link. Abrir uma referência não conclui a aula automaticamente.

O editor da aula permite ativar/desativar a referência e preencher formato,
título, autor, resumo, link principal, capa e link de áudio opcional. A estrutura
JSON é opcional e compatível com aulas antigas, sem necessidade de novas colunas.

As referências iniciais são compartilhadas pelas aulas do respectivo programa.
Fontes verificadas em 26/10/2026:

- Fundamentos: [Gino Terentim — TEDxESMPU](https://www.ted.com/talks/gino_terentim_como_superar_paradigmas_que_protegem_e_limitam_sua_vida).
- Liderança: [Janaina Faria Fidelis Borges — Sebrae Play](https://www.sebraeplay.com.br/content/lideranca-alem-do-cargo).
- Estoicismo: [Ivan Biava — Papo Estoico](https://estoicismopratico.com/papo-estoico/autocontrole-estoicismo-1---dicotomia-do-controle-elimine-a-ansiedade-e-foque-no-que-importa), com opções YouTube e Spotify vinculadas pelo autor.
- Corpo: [Drauzio Varella — Portal Drauzio](https://drauziovarella.uol.com.br/videos/sente-dores-no-corpo-pode-ser-o-sedentarismo/).
- Niilismo: [O Niilismo EXPLICADO — Ciência Todo Dia](https://www.youtube.com/watch?v=2t1vB8TeUUc). Título, canal e capa conferidos pelo oEmbed do YouTube. O programa diferencia o questionamento filosófico dos riscos práticos de apatia e indiferença, sem tratar esses riscos como consequências inevitáveis.

Para a contextualização de Nietzsche e da criação de valores, foi consultado o
verbete [Friedrich Nietzsche — Stanford Encyclopedia of Philosophy](https://plato.stanford.edu/entries/nietzsche/).

Links externos e suas imagens podem mudar. O material pode ser atualizado por
aula sem alterar as leituras e práticas ou o progresso dos alunos.

## Verificação

`flutter test test/program_learning_test.dart` cobre catálogo/seed, requisitos de
publicação, progresso persistente, concorrência local, combinação de aparelhos,
fila offline, isolamento de contas, busca/retomada em tela estreita e edição
administrativa. Testes HTTP usam respostas simuladas: não substituem a validação
das policies e da função SQL em uma instância Supabase com as migrations aplicadas.

Após aplicar as migrations, conferir com visitante, membro e administrador:

- Visitante não consegue ler rascunhos ou progresso de membros.
- Membro só lê seu progresso e não consegue editar o catálogo.
- Administrador cria um rascunho, pré-visualiza e publica; membro consegue abri-lo.
- Dois aparelhos concluem aulas diferentes; ambos recebem as duas conclusões.
- Despublicar remove o programa da próxima atualização online do catálogo.
