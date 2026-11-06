# Notificar membros ao publicar na comunidade

## Uso

No formulário de nova publicação, a conta do líder vê **Notificar todos os membros**. A opção começa desligada e não é ativada automaticamente ao restaurar um rascunho. Quando selecionada, o app salva a publicação e coloca o aviso na fila do servidor. Publicações comuns continuam sem aviso geral.

O aviso aparece também na central de notificações do app. Ao tocar no aviso pelo app, navegador ou Android, a publicação correspondente é aberta. Os links aceitos para navegação interna usam o domínio do PBH e um UUID de publicação válido. No Android, o destinatário do payload deve corresponder à conta conectada; avisos antigos de outra conta não abrem conteúdo automaticamente.

## Segurança e repetição

- A opção é apresentada pela marca de líder em `app_metadata`, controlada pelo servidor. A RPC confirma novamente a marca protegida, a confirmação da conta e que a publicação pertence ao solicitante. Ser apenas administrador não habilita o envio geral.
- O banco vincula um único aviso e trabalho de entrega a cada publicação. Repetir a chamada retorna o aviso existente. A fila é persistente e funciona sem o formulário continuar aberto.
- Se salvar o post funcionar, mas não houver confirmação do agendamento, o formulário informa isso. Repetir com o mesmo ID de rascunho tenta agendar o aviso sem criar outro post.
- Ao excluir o post, o trabalho e o aviso associados são removidos. Uma notificação já aceita pelo provedor ou que esteja sendo enviada não pode ser recolhida do aparelho.
- O envio usa a fila e os comprovantes de entrega já existentes. Isso reduz repetições em novas tentativas, mas não é uma garantia de entrega exatamente uma vez em falhas de rede com resposta perdida.
- Chaves FCM, VAPID e `service_role` continuam exclusivamente no servidor.

## Ativação no Supabase

1. Confirmar que a migração de agendamento `20261023000100_scheduled_announcements.sql` e a identidade protegida do fundador `20261105000400_private_founder_identity_support.sql` já foram aplicadas.
2. Aplicar `supabase/migrations/20261105000700_leader_post_broadcasts.sql`, seguindo a sequência das migrações do projeto. A instalação não envia avisos sozinha.
3. Reimplantar a função existente com os arquivos atualizados:

   ```sh
   supabase functions deploy process-announcement-schedules
   ```

   O deploy inclui o módulo compartilhado `_shared/native-push.ts` atualizado. Não é necessário criar um novo endpoint de envio.
4. Conferir as configurações já usadas no projeto: `FCM_SERVICE_ACCOUNT_JSON` nos segredos da função, `ANNOUNCEMENT_CRON_SECRET`, valores privados `pbh_announcements_project_url` e `pbh_announcements_cron_secret` no Vault, e o cron `pbh-announcement-scheduler`. Para navegadores, conferir também VAPID. A entrega Android passou a funcionar independentemente da presença das chaves de Web Push.
5. Atualizar o app com o código novo. No Flutter/VS Code, fazer Hot Restart. O toque da notificação Android precisa da versão nova do aplicativo; APKs antigos podem apenas abrir o app.

Essas ações de implantação remota **não foram executadas nesta tarefa**. Nenhum aviso real foi enviado aos membros durante o desenvolvimento.

## Limites da entrega

“Todos” é a audiência da comunidade, incluindo administradores. O push só pode chegar aos dispositivos ou navegadores cadastrados que permitiram notificações e continuam com token válido. Preferências de som e canais existentes são respeitadas. Configurações do Android, conexão, bateria e o provedor podem atrasar ou impedir a entrega.

O banco registra o aviso imediatamente; o processamento do push depende da função e da fila. O scheduler tenta iniciar o envio e o cron periódico retoma trabalhos pendentes. Se a função não estiver implantada ou os segredos estiverem ausentes, a existência do aviso no app não comprova que um celular recebeu o push. Os estados e métricas dos avisos continuam disponíveis no Admin.

## Validação

- Teste SQL: membro/administrador sem marca de líder, conta não confirmada e post de outro autor são rejeitados; repetir o envio mantém um só aviso e trabalho; excluir o post remove os registros associados.
- Teste do worker com dependências simuladas: chamadas sem segredo são rejeitadas e a entrega Android continua quando não há chaves de Web Push.
- Testes Flutter: opção exclusiva e desligada inicialmente; repetição após falha de confirmação não duplica o post; links inválidos, externos ou destinados a outra conta são ignorados.
- Suíte completa: **254 testes Flutter passaram**. Sem teste de entrega real em celular nesta tarefa.

Não houve commit, push, publicação ou geração de APK nesta tarefa.

## Visual dos avisos da comunidade

O visual foi separado dos avisos gerais:

- Ícone de pessoas em branco sobre laranja PBH, com um ícone monocromático próprio para a barra de status Android.
- Canal **Comunidade**, título **🔥 Post em destaque** e texto **Nome atual: prévia da publicação…**. O nome vem da identidade atual do autor no servidor; a prévia é limitada e não inclui quebras de linha.
- No app, o cartão da comunidade mostra a seção e o horário acima do título, mantendo as cores e a tipografia do projeto. Avisos gerais mantêm sua apresentação anterior.
- No Android com app aberto, o aviso usa o canal específico, subtítulo da comunidade e expansão de texto. No recebimento em segundo plano, o FCM usa o canal, ícone e cor próprios; não é enviada uma imagem de capa grande para esse tipo de aviso.
- A moldura, a transparência, o local exato do ícone e a exibição do horário são controlados pelo sistema do celular. Não foi criado um layout que substitua os controles do Android ou que prometa reproduzir exatamente um cartão de iOS.

Para ativar o formato novo, aplicar `20261105000800_community_notification_design.sql` **após a 007**, reimplantar `process-announcement-schedules` e `send-announcement` (ambas usam os módulos compartilhados atualizados) e publicar o arquivo web `icons/community-192.png` junto com o build web. Os ícones e canais Android novos entram no próximo APK; ele não foi gerado nesta alteração. Avisos já criados não são reescritos nem reenviados pela migração.

O ícone é gerado de formas simples pelo script `tools/generate-community-notification-icon.dart`. Testes verificaram o nome atual, o título e o limite da prévia no banco, o canal silencioso, a preservação dos avisos gerais e a entrega Android independente de chaves web. Não houve envio real para aparelhos ou implantação remota durante essa alteração.

### Revisão visual posterior: mensagem do líder

O modelo laranja foi substituído pelo exemplo roxo enviado depois: **PBH Oficial**, título **👑 Mensagem do Líder**, logo PBH e prévia com o nome atual do autor. Na central do app o cartão tem gradiente escuro roxo, borda discreta e horário no cabeçalho. No Android o aviso usa a marca PBH e o acento roxo; não há substituição da moldura ou da transparência controladas pelo sistema.

Aplicar `20261105000900_leader_message_notification_design.sql` após a 008 e reimplantar as duas funções de envio para ativar o novo formato no servidor. O visual local completo entrará no próximo APK. O build 52 entregue anteriormente não foi alterado. Não houve deploy, envio real, commit ou push nesta revisão visual.
