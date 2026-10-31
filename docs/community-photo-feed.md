# Comunidade PBH: mural com relatos e fotos

## Ativação

Depois das migrações anteriores da comunidade, execute o arquivo completo
`supabase/migrations/20261030000100_community_photo_feed.sql` no SQL Editor.
Não reaplique as migrações antigas. Esta etapa não cria outra comunidade,
Edge Function, cron, IA ou integração paga.

Para GIFs, vídeos e a identidade atualizada, execute em seguida
`supabase/migrations/20261030000200_community_media_identity.sql`.
Quem já executou a migração 001 deve executar apenas a 002.

Para artes HTML, execute depois a migração
`supabase/migrations/20261030000300_community_html_art.sql`.
No formulário, use **HTML** e escolha um documento completo UTF-8 de até 5 MB.
O arquivo mantém CSS/JavaScript internos, é armazenado como `text/plain` e
renderizado no mesmo sandbox das capas. Recursos externos, acesso à conta,
navegação e formulários são bloqueados. Imagens/fontes precisam estar
embutidas no arquivo. A arte aparece no feed e ao ampliar; movimento reduzido,
rolagem e segundo plano seguem as regras do visualizador das capas.
Publicações antigas que enviaram uma captura da arte continuam sendo imagens;
é preciso enviar novamente o HTML pelo novo botão para ter animação.

A migração adiciona `image_paths` aos posts e à view `community_feed`, configura
o bucket privado `community-photos` e as permissões de upload, leitura e limpeza.
Antes dela, o aplicativo consegue ler os posts antigos, mas a nova publicação
com identificação de rascunho e fotos depende dessa estrutura.

## Experiência

- Caixa **Compartilhe sua jornada** no topo, com avatar e entradas Relato/Fotos.
- Publicação com texto, assunto e até quatro anexos. Fotos JPG, PNG e WebP:
  5 MB; GIFs originais animados: 10 MB; vídeos MP4 ou WebM: 25 MB por arquivo.
  O seletor de fotos solicita redução para 1600 px quando a plataforma suporta.
- GIFs e vídeos têm seletores separados e preservam seus bytes originais.
  Vídeos abrem com controles de reprodução, pausa e posição; não tocam no feed.
  A compatibilidade de codecs depende do navegador/dispositivo. Para maior
  compatibilidade, use MP4 com H.264/AAC. O player atende Chrome e Android;
  não foi validado em aparelho físico nesta alteração.
- Nome e foto próprios vêm da sessão atual e reagem às alterações de perfil.
  A identidade dos demais autores é consultada ao montar o card e atualizada
  automaticamente a cada 30 segundos com o app aberto, respeitando privacidade
  e bloqueios. Comentários usam a mesma identidade. A RPC retorna somente nome,
  avatar e identificação de fundador; não concede leitura da tabela profiles.
- Prévia e remoção individual antes do envio. O botão de publicar fica fixo.
- Erros de envio preservam texto e fotos enquanto o formulário continua aberto.
  Sair de um rascunho pede confirmação. O rascunho não é persistido após fechar
  o aplicativo ou descartar o formulário.
- Fotos em galeria, com ampliação em tela cheia, zoom e navegação entre imagens.
- Recentes, Seguindo e Em destaque no acesso principal. **Em destaque** significa
  mais curtidos, não curadoria administrativa. Conquistas e Salvos continuam no
  menu de filtros; busca e assuntos ficam em uma seção recolhida.
- Números da comunidade ficam recolhidos ao fim do feed. O botão de informações
  reúne apresentação, combinados e a pergunta semanal, com acesso para responder.
- O mural vazio não cria posts de demonstração nem inventa atividade de membros.

## Dados e permissões

O conteúdo da comunidade, inclusive fotos, é visível também a visitantes.
Tornar um perfil privado oculta nome/foto do autor conforme as regras existentes,
mas não torna privadas suas publicações. O formulário informa isso antes do envio.
O feed e a autorização das fotos respeitam bloqueios nos dois sentidos para a
sessão conectada. URLs assinadas valem por dez minutos; uma URL já compartilhada
pode continuar válida até expirar. Use Recarregar fotos ou atualizar o feed para
renovar os endereços.

Somente o autor pode reservar/enviar fotos para a pasta da publicação. O banco
valida quantidade, duplicatas, pasta e existência dos arquivos antes de aceitar
o post. Os arquivos ainda associados a um post não podem ser apagados pelo fluxo
de limpeza. Curtidas, comentários, salvamentos e denúncias usam os fluxos existentes.

Cada rascunho usa um ID estável. Se a resposta se perder após a publicação,
a nova tentativa reconhece o mesmo post, evitando duplicação e exclusão de suas fotos.
Reservas guardam arquivos de envios interrompidos. Após quinze minutos, eles podem
ser removidos pela limpeza; posts excluídos entram na fila imediatamente.
Ao abrir o feed, o autor ou um administrador processa até dez itens de limpeza.
Falhas mantêm a fila para outra tentativa. Não existe limpeza contínua com o app
fechado; arquivos podem continuar consumindo espaço até uma próxima visita.

As fotos usam o armazenamento e o tráfego do Supabase existente. O limite por
publicação reduz consumo, mas não elimina a necessidade de acompanhar a cota.

## Validação

`test/community_photos_test.dart` verifica limites, rascunho, retentativa e descarte.
`test/community_identity_test.dart` verifica atualização de nome/avatar e remoção
da imagem. `test/community_video_test.dart` simula o player para verificar toque,
pausa ao trocar de página, segundo plano e descarte do controlador.
`test/community_photo_service_test.dart` cobre upload, resposta perdida e falha
na assinatura das fotos sem esconder o texto. `supabase/tests/community_photo_feed_test.ts`
usa PostgreSQL embarcado para validar propriedade, bloqueios, leitura anônima,
arquivos associados a posts e a fila de limpeza. Os testes não alteram o Supabase real.

Após a ativação, conferir no projeto real com duas contas e um visitante: publicar
quatro fotos, ampliar, comentar, bloquear, excluir e atualizar o mural.
