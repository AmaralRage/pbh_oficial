# Melhorias de 31/10/2026

## Ativação no Supabase

Após as migrações anteriores, execute os arquivos completos, em ordem:

1. `supabase/migrations/20261031000100_community_editor_activity.sql`
2. `supabase/migrations/20261031000200_goal_history.sql`

Use o código desta atualização junto das migrações. O salvamento de objetivos
passa a usar RPCs para preservar o histórico e detectar edições concorrentes;
versões antigas que gravam diretamente na tabela precisam ser atualizadas.
O APK build 49 distribuído anteriormente ainda não contém estas alterações.

## Comunidade

- O autor edita o texto no menu da publicação. Anexos são mantidos. A edição
  é indicada no card e rejeitada se outro aparelho já mudou o texto.
- Somente o fundador com email confirmado fixa seus próprios avisos: até três.
  Avisos ficam primeiro na ordenação por data, respeitando filtros e bloqueios.
- O botão de conversas junto ao título abre as últimas 50 respostas recebidas.
  Selecionar uma abre a publicação com seus comentários e marca o aviso como lido.
  A lista é consultada a cada 30 segundos com o app em primeiro plano. São avisos
  dentro da comunidade, sem novo push de sistema ou envio de email.
- Respostas próprias não geram aviso. Exclusão do comentário/post exclui o aviso;
  bloqueios do autor do post ou da resposta também ocultam o item.

## Rascunhos

Há um rascunho local por conta. Texto, assunto, conquista e os bytes originais
dos anexos são salvos após uma pausa na edição e ao escolher guardar/sair.
O identificador da publicação é preservado para evitar duplicação em retentativas.
Publicar ou descartar apaga o rascunho. Não há cópia na nuvem nem recuperação
após limpar os dados do app/navegador. O salvamento depende de espaço disponível;
falhas são mostradas. O último instante antes de um encerramento forçado pode
não ter sido gravado. Outra conta não lê o rascunho anterior pelo aplicativo.

## Personalização

Capas, molduras e backgrounds têm miniaturas para seleção. As prévias pequenas
são estáticas para não executar dezenas de animações simultaneamente. Recompensas
continuam bloqueadas, e a Coroa Suprema permanece oculta para quem não a recebeu.
O envio de foto/capa/background estático abre posicionamento e zoom. O resultado
é PNG; GIF/HTML da capa continuam sem conversão. Escolher outro recorte exige
reabrir o arquivo original: partes descartadas não são recuperáveis do PNG salvo.

## Objetivos

Concluir um objetivo guarda um resumo privado e mantém os avanços ligados ao
identificador daquele objetivo. Depois é possível começar outro. O histórico e
a linha do tempo têm paginação. Objetivos concluídos saem do perfil público.
Registros anteriores à migração continuam privados em uma seção própria: não
se inventa vínculo com o objetivo atual nem uma data de início desconhecida.

## Música e validação

Sem player integrado, o botão abre a playlist oficial. Se o aplicativo Spotify
não puder abrir, há tentativa pelo endereço web. Conexão e controles integrados
dependem da configuração e da sessão Spotify existentes; não foram autenticados
ou verificados em conta real nesta alteração.

Foram executados testes de widgets/serviços, PostgreSQL embarcado e um teste
real no Chrome salvando 7 MB no IndexedDB, recarregando a página, recuperando e
excluindo os dados. O backend nativo de arquivos e a exportação PNG do recorte
também têm testes. Não havia Android conectado ao ADB: reprodução de mídia,
OAuth, notificações de sistema e desempenho físico permanecem para validação
em aparelho. Testes locais não equivalem a essa validação.
