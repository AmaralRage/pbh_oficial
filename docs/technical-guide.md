# PBH Oficial

> Atualização de 27/10/2026: consulte também [sincronização, notificações e distribuição](reliability-and-release.md)
> para as migrations novas, a assinatura e os APKs com nome padronizado.

## Executar no navegador

Se `flutter run -d chrome` encerrar com `WipError -32000 Cannot find context with
specified id`, inicie o servidor web e abra o endereço manualmente. Isso evita
a etapa de conexão automática ao depurador do Chrome:

Na raiz do projeto, execute `./run_web.bat` no PowerShell e abra
`http://127.0.0.1:7357/` depois que a compilação terminar. Mantenha o terminal
aberto. Esse caminho contorna a falha do depurador; não altera o SDK Flutter.
O comando equivalente é:

```powershell
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=7357 --dart-define=SPOTIFY_CLIENT_ID=59ea8a21516947b1936233d03ea53f31
```

Abra `http://127.0.0.1:7357/`. Para testar também o login Spotify nesse endereço,
cadastre `http://127.0.0.1:7357/` nas Redirect URIs do Spotify Dashboard.

## Autenticação Supabase

O app usa Supabase Auth com e-mail e senha. Ative a confirmação de e-mail nas
configurações de autenticação do projeto, configure os modelos de confirmação e
recuperação de senha e permita a URL do app em **Authentication → URL
Configuration → Redirect URLs**.

Passe a URL e a chave publicável do projeto ao compilar a versão Web:

```powershell
flutter build web `
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA
```

Antes de testar o login, aplique a migration
`supabase/migrations/20261015000100_profiles_and_initial_admin.sql` pelo SQL
Editor do Supabase ou pelo Supabase CLI. Ela cria perfis com Row Level Security
e promove `amaralaragao31@gmail.com` a admin somente depois da confirmação do
e-mail. O cliente não pode alterar o próprio papel.

O link de recuperação retorna ao app e abre a tela para definir uma nova senha.

## Player Spotify

O player web usa o Spotify Web Playback SDK. Cada pessoa conecta a própria conta
Spotify Premium; o app não recebe senha nem Client Secret. Para habilitar:

1. Crie um app no [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Cadastre `https://pbh-oficial.vercel.app/` como Redirect URI nas configurações do app. Durante o desenvolvimento local, cadastre também a URL local que você usa, como `http://localhost:7357/`.
3. Adicione o Client ID como variável de repositório `SPOTIFY_CLIENT_ID` em GitHub → Settings → Secrets and variables → Actions → Variables.
4. Publique um novo build pela workflow de deploy.

O player inicia a playlist oficial neste navegador, mostra a faixa atual e oferece
controles de pausa, avanço, retorno e posição. Letras são consultadas faixa a faixa
na LRCLIB; a cobertura depende do catálogo externo. Se uma faixa não tiver letra,
o player informa isso sem interromper a reprodução.

O Spotify Web Playback SDK exige Premium e pode ter restrições de reprodução em
segundo plano nos navegadores móveis. Revise também os termos do Spotify para
confirmar que o uso no seu app se enquadra nas regras da plataforma.

No Development Mode do Spotify, o app fica limitado a cinco usuários autorizados
e se destina a testes e uso pessoal não comercial. Para disponibilizar o player
para a comunidade inteira do PBH, será necessário obter acesso ampliado do Spotify.
Veja o [guia de mudanças do Development Mode](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide).

### Spotify no Android e iOS

O player mobile mantém OAuth com PKCE para conectar a conta e consultar a playlist.
No Android, o SDK oficial Spotify App Remote inicia e controla o Spotify como
serviço em segundo plano, mantendo o player do PBH aberto. A primeira conexão
pode mostrar a autorização do Spotify; reproduzir não abre links externos.
Capa, progresso e estado vêm do SDK; letras continuam sendo consultadas pela faixa.
Pausa, avanço, retorno, busca, reprodução aleatória e repetição usam o SDK.
É necessário Spotify instalado, usuário conectado e permissões da conta; os
controles completos exigem Premium. No iOS, permanece o controle via Spotify
Connect, sem redirecionamento automático; App Remote iOS ainda não foi integrado.
As consultas param quando o PBH fica em segundo plano; o áudio continua no Spotify.

No Dashboard, habilite Android e cadastre o pacote `com.amaralstudios.pbh_oficial`
com o SHA-1 do certificado que assina o APK. Para o APK de teste desta máquina:
`2F:E3:93:94:75:04:3C:D0:E0:1E:2F:55:94:D3:ED:1F:D6:79:8E:5B`.
Se a chave de assinatura mudar, registre também sua nova impressão digital.

O AAR oficial 0.8.0 e a licença estão em `android/app/libs/`, obtidos do repositório
`spotify/android-sdk`, revisão `5aa4d62465f61a0677081ae9a3108177d0365fc3`.
SHA-256 do AAR: `B5A6DD880EAF01F63A871CBA9EF7AF77C341F8A94FFC8FDF2E9021F9A9D4C198`.

No mesmo app do Spotify Developer Dashboard usado na web, cadastre exatamente
`pbh-oficial://spotify-callback` em **Redirect URIs**. O Client ID público mobile
já está configurado e pode ser substituído com `--dart-define=SPOTIFY_CLIENT_ID=...`.
Não use Client Secret no aplicativo. Os tokens são mantidos apenas na memória
durante a sessão; ao encerrar o processo será preciso conectar novamente.
Desconectar remove a sessão Spotify do PBH, sem deslogar o aplicativo Spotify.

Para gerar o APK de testes: `flutter build apk --debug --build-number=3`.
As restrições de usuários em Development Mode e de leitura de playlists também se
aplicam ao mobile. Android e iOS têm o retorno OAuth configurado no projeto; a
compilação e validação em aparelho iOS dependem de Mac/Xcode.

## Dados persistentes

### Selos animados no perfil

O perfil destaca os principais selos já conquistados, com os maiores marcos de
rotina, desafios e comunidade. Ao tocar, a arte e a descrição abrem ampliadas.
O selo de meditação **Ascensão suprema** usa a arte animada local
`assets/images/trofeu_supremo_meditacao.png` como miniatura e exibe o HTML
original com seus efeitos na visualização ampliada, tanto no mobile quanto na web.
Ele pertence ao criador do projeto e só é concedido a outras contas manualmente.

Para habilitar a concessão, aplique
`supabase/migrations/20261021000100_profile_achievement_awards.sql` no Supabase,
após as migrations anteriores. A conta confirmada do líder pode então usar
**Perfil > Selos de dedicação > Conceder selo supremo**, escolhendo o selo e informando o e-mail
confirmado da pessoa. O servidor valida o líder; outras contas não podem gravar
concessões diretamente. A pessoa recebe o selo ao recarregar/abrir o perfil.
Sem a migration, o perfil continua exibindo as conquistas existentes e o líder
já vê seu selo; as concessões a outras pessoas dependem da instalação da migration.

O selo de treino **Força suprema** usa `assets/images/Troféu supremo de treino.html`
na expansão e uma miniatura da própria arte no perfil. Ele segue a mesma regra de
concessão manual e já pertence ao líder. A migration
`20261021000200_supreme_training_seal.sql` adiciona esse selo à lista permitida
sem modificar as concessões existentes de meditação.

O selo **Sabedoria suprema**, de leitura, usa o HTML original
`assets/images/Troféu supremo de leitura.html`, com páginas luminosas e runas.
Segue a concessão manual e já pertence ao líder. A migration
`20261021000300_supreme_reading_seal.sql` habilita sua concessão, preservando os
selos de treino e meditação já concedidos.

O selo **Mente limpa**, do desafio sem pornô, usa
`assets/images/Troféu supremo sem pornô.html`, com o cristal azul e suas animações.
Também pertence ao líder e é concedido manualmente às demais contas. A migration
`20261021000400_supreme_porn_free_seal.sql` habilita essa concessão preservando
os três selos anteriores.

A **Platina PBH** usa `assets/images/Trofeu_Platina_PBH.html` na visualização
ampliada e sua própria miniatura no perfil e no card de conquistas. Ela permanece
vinculada à conclusão de todos os desafios do catálogo, sem concessão manual.

O marco de **2000 dias de dedicação** usa `assets/images/Trofeu_2000_completo.html`
com a chama e os efeitos âmbar originais na expansão. A miniatura é exibida no selo
de constância quando o marco de 2000 dias for o maior já alcançado. O critério de
dias permanece o mesmo: sequência da rotina para membros e dias de projeto para
o líder, sem concessão manual desse marco.

Depois das migrations existentes, aplique também `20261019000300_community_access_performance.sql`. Ela corrige a leitura segura necessária para salvar curtidas e reduz consultas repetidas no feed e nos comentários.

Aplique as migrations em ordem: `20261015000100_profiles_and_initial_admin.sql`, `20261015000200_announcements.sql`, `20261015000300_community_progress.sql`, `20261015000400_admin_notification_center.sql`, `20261017000100_profile_privacy.sql`, `20261017000200_expanded_challenges_and_leader_name.sql`, `20261017000300_community_discovery_moderation.sql`, `20261019000100_habit_routine_reminders.sql` e `20261019000200_community_interactions_avatars.sql`. A migration `20261017000200` adiciona 52 desafios (57 no total). A migration `20261015000400` adiciona segmentação por papel, links de destino, rascunhos e métricas administrativas. A migration `20261017000300` habilita temas, denúncias com motivo, bloqueios e revisão administrativa da comunidade. A migration `20261019000100` cria as preferências e o controle de envio dos lembretes da rotina. A migration `20261019000200` salva curtidas e comentários dos cards de exemplo, inclui foto pública nos comentários e limita a exclusão ao autor. Fotos de perfil são lidas dos metadados `avatar_url`, `picture` ou `avatar` do usuário autenticado; perfis privados ocultam a foto e o nome no feed. As políticas RLS limitam alterações à conta autenticada e ao papel de administrador.

## Notificações push Web

O realtime funciona enquanto o app está aberto. Para avisar com o app em segundo plano, gere um par VAPID localmente. Nunca coloque a chave privada no app ou no repositório.

```powershell
npx --yes web-push generate-vapid-keys
supabase login
supabase link --project-ref xbwspizvpcnjxvlylcvx
supabase secrets set VAPID_PUBLIC_KEY=SUA_CHAVE_PUBLICA VAPID_PRIVATE_KEY=SUA_CHAVE_PRIVADA VAPID_SUBJECT=mailto:amaralaragao31@gmail.com
supabase functions deploy send-announcement
flutter build web `
  --dart-define=SUPABASE_URL=https://xbwspizvpcnjxvlylcvx.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA_SUPABASE `
  --dart-define=WEB_PUSH_VAPID_PUBLIC_KEY=SUA_CHAVE_VAPID_PUBLICA
```

Depois de publicar o site em HTTPS, cada pessoa ativa “Notificações no navegador” em Perfil > Configurações > Notificações. A Edge Function verifica o papel de administrador e o público selecionado antes de enviar os avisos. A taxa de envio representa notificações aceitas pelo serviço push do navegador; a taxa de leitura vem das confirmações registradas dentro do app. A chave pública VAPID do projeto já possui um valor padrão no cliente web; uma definição explícita no build pode substituí-la. Nunca substitua o par VAPID sem planejar a renovação das inscrições existentes.

### Mensagens administrativas agendadas

Na aba **Histórico**, o ícone de lixeira exclui um aviso após confirmação e remove a mensagem da central de todos os usuários. A lista permite carregar notificações mais antigas. A migration `20261023000300_admin_delete_announcements.sql` restringe a operação a administradores, remove recibos vinculados e encerra novas tentativas pendentes de agendamentos já publicados. O registro do agendamento fica marcado como excluído. Avisos já entregues ou em processamento nos dispositivos não podem ser recolhidos. A central e o contador do sino atualizam quando recebem o evento de exclusão. O teste `supabase/tests/admin_delete_announcements.sql` valida a operação com fixtures revertidas, sem apagar mensagens reais.

Na central administrativa, escolha **Agendar envio**, selecione a data e o horário e confirme em **Agendar notificação**. A aba **Agendadas** lista as últimas 100 programações da sua conta, permite atualizar o status e cancelar envios ainda pendentes. Os horários usam o fuso local do aparelho que agenda e são salvos em UTC. Rascunhos salvam o conteúdo; o horário é definido ao confirmar o agendamento.

A migration `20261023000100_scheduled_announcements.sql` instala `pg_cron`, `pg_net`, a fila protegida por RLS e o job `pbh-announcement-scheduler`. Ele verifica a fila a cada minuto, publica mensagens vencidas na central do app e chama a função `process-announcement-schedules` para o push web. A publicação é atômica e não se repete em execuções concorrentes. Um cancelamento que chegar depois da publicação é recusado. O papel de administrador é verificado ao agendar e novamente ao publicar. Se houver indisponibilidade do servidor, mensagens pendentes são processadas quando ele retomar.

O worker exige o segredo `ANNOUNCEMENT_CRON_SECRET`, também armazenado no Vault como `pbh_announcements_cron_secret`. A URL fica no segredo `pbh_announcements_project_url`. As chaves `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` e `VAPID_SUBJECT` configuram o push. Esses valores privados não pertencem ao repositório. A instalação no projeto vinculado foi realizada em 23/10/2026.

O worker reserva cada envio com uma concessão de cinco minutos, tenta até cinco vezes e registra os endpoints já processados para não reenviar pushes confirmados. Como em outros sistemas de push, uma interrupção entre a aceitação pelo provedor e a gravação do recibo ainda pode causar repetição; a mesma `tag` de notificação reduz duplicatas visuais. Aceitação pelo provedor não confirma entrega/leitura no aparelho. Falha no push não desfaz a mensagem publicada na central. A aba Agendadas distingue publicação e processamento do push. O APK recebe a mensagem na central ao abrir/sincronizar; aviso remoto com o APK fechado requer uma integração nativa adicional.

Validação: `supabase/tests/scheduled_announcements.sql` usa fixtures em transação revertida para testar permissões, data futura, cancelamento, publicação única, remoção de privilégios administrativos, concessões e limite de tentativas. Execute com `supabase db query --linked --file supabase/tests/scheduled_announcements.sql`. Não execute fixtures de entrega contra usuários reais. Para inspecionar o agendador, consulte `cron.job` e `cron.job_run_details`; não exponha os valores do Vault.

### Notificações remotas no APK Android

O PBH mantém autenticação, dados, públicos e agendamentos no Supabase. O Firebase Cloud Messaging (FCM) transporta o aviso para a barra de notificações do Android. A integração está preparada, mas a entrega depende das configurações abaixo, ainda não fornecidas pelo proprietário:

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com/) e registre o aplicativo Android com pacote `com.amaralstudios.pbh_oficial`.
2. Salve o arquivo **google-services.json** em `android/app/google-services.json`. O Gradle aplica a configuração somente quando esse arquivo existe. Sem ele, o app continua funcionando e informa que o push nativo está pendente.
3. Em **Configurações do projeto > Contas de serviço**, gere uma credencial de servidor autorizada a enviar via FCM HTTP v1. Salve-a localmente, por exemplo em `build/firebase-service-account.json`, e configure seu conteúdo no segredo `FCM_SERVICE_ACCOUNT_JSON` das Edge Functions. Nunca adicione a chave privada ao APK, ao repositório ou à conversa. Habilite a API Firebase Cloud Messaging HTTP v1 do projeto, se necessário.
4. Aplique `20261023000200_native_push_tokens.sql` e publique `send-announcement` e `process-announcement-schedules`, incluindo `functions/_shared/native-push.ts`. Esses componentes guardam os dispositivos sob controle do servidor e respeitam o público escolhido. O segredo só é necessário quando existem celulares elegíveis para receber.
5. Gere e instale um novo APK. Na primeira abertura, permita os avisos no pedido do Android. Ao entrar na conta, o dispositivo é cadastrado automaticamente. Para desativar ou reativar depois, use **Configurações > Notificações > Receber notificações**; o botão **Ativar neste dispositivo** permite tentar novamente caso necessário. Teste com o app em segundo plano e com o processo encerrado normalmente. Não use **Forçar parada**: o Android suspende a entrega até a próxima abertura.

Os tokens são renovados automaticamente e trocam de proprietário quando a conta do aparelho muda. O logout revoga o cadastro antes de sair. Tokens não podem ser lidos diretamente por usuários do app. Recibos evitam repetir entregas já confirmadas; endpoints expirados são removidos. Avisos imediatos e agendados usam o mesmo transporte FCM; avisos em primeiro plano usam o canal local correspondente. O toque em uma notificação abre o app. A primeira abertura solicita permissão uma vez por instalação. Recusas e desativações são persistidas; o pedido não se repete automaticamente. No navegador, a ativação continua pelo botão nas configurações. A implementação desta etapa cobre Android; iOS exige configuração APNs própria antes de habilitar esse fluxo.

Validações: `supabase/tests/native_push_tokens.sql`, `npx deno test --allow-env supabase/functions/_shared/native-push_test.ts`, testes Flutter e compilação Android. A entrega física em um aparelho só pode ser verificada depois de configurar o Firebase e registrar um celular real.

### Lembretes automáticos da rotina

Os lembretes podem ser ativados em **Rotina de Hábitos**. No app Android/iOS, cada tarefa pendente recebe um aviso próprio no prazo automático (treino 20h; leitura e meditação 21h; foco 21h30; descanso 22h), e o horário escolhido pela pessoa continua como lembrete geral. A conclusão das tarefas atualiza os avisos locais. No navegador, o push envia no máximo um aviso por dia, no primeiro prazo pendente ou no horário escolhido. As notificações usam a identidade visual do PBH e mensagens relacionadas à tarefa. Para o site, é necessário HTTPS, permissão do navegador, aplicar a migration `20261019000100_habit_routine_reminders.sql`, configurar a Edge Function e o cron. Em iPhone/iPad, push web pode exigir que o site esteja instalado na tela inicial.

O envio usa os segredos VAPID já configurados acima e uma chave compartilhada exclusiva para o cron. Gere uma chave longa e aleatória, guarde-a fora do repositório e configure a Edge Function:

```powershell
supabase secrets set HABIT_REMINDER_CRON_SECRET=SUA_CHAVE_LONGA_E_ALEATORIA
supabase functions deploy send-habit-reminders --no-verify-jwt
```

No SQL Editor do Supabase, habilite `pg_cron` e `pg_net` em **Database > Extensions**. Depois crie dois segredos no Vault: a URL do projeto e a mesma chave usada em `HABIT_REMINDER_CRON_SECRET` (substitua os valores de exemplo):

```sql
select vault.create_secret('https://xbwspizvpcnjxvlylcvx.supabase.co', 'pbh_project_url');
select vault.create_secret('SUA_CHAVE_LONGA_E_ALEATORIA', 'pbh_habit_reminder_cron_secret');
```

Agende a verificação a cada minuto:

```sql
select cron.schedule(
  'pbh-habit-routine-reminders',
  '* * * * *',
  $$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'pbh_project_url') || '/functions/v1/send-habit-reminders',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-pbh-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'pbh_habit_reminder_cron_secret')
      ),
      body := '{}'::jsonb
    );
  $$
);
```

O cron apenas verifica os horários configurados; o banco usa o fuso local de cada pessoa para decidir quando enviar. Para revisar ou remover o agendamento, consulte `cron.job` e use `cron.unschedule(jobid)` no SQL Editor.

### Notificações locais nos apps Android e iOS

As pastas `android/` e `ios/` permitem instalar o mesmo app Flutter nos celulares. Na **Rotina de Hábitos**, ao ativar o lembrete no app instalado, o sistema operacional agenda a notificação no aparelho. No Android, permita tanto notificações quanto **Alarmes e lembretes** para que o horário escolhido seja pontual; o app solicita esse acesso ao ativar os lembretes. O Firebase, o Google e o cron de push web não participam desse envio local. A rotina e as preferências ainda usam a conta PBH/Supabase para sincronizar os dados.

Para executar no Android, conecte um aparelho ou inicie um emulador e rode:

```powershell
flutter run -d SEU_DEVICE_ID `
  --dart-define=SUPABASE_URL=https://xbwspizvpcnjxvlylcvx.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA_SUPABASE
```

Para gerar o APK:

```powershell
flutter build apk `
  --dart-define=SUPABASE_URL=https://xbwspizvpcnjxvlylcvx.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICA_SUPABASE
```

O Vercel continua servindo a versão web sem alterações no endereço. Para compilar ou publicar o app iOS é necessário abrir o projeto em um Mac com Xcode; a pasta iOS já está criada. O build iOS recebe as mesmas variáveis `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`. No iOS, também é necessário assinar o app com uma conta Apple para instalar em aparelhos físicos.

Os lembretes nativos são agendados localmente e atualizados quando o app abre a rotina ou quando a pessoa marca/desmarca tarefas. Como o sistema operacional executa o aviso, ele pode aparecer com o app fechado. Enquanto o aparelho estiver sem abrir o app, ele não consegue consultar mudanças novas na conta PBH; ao voltar a abrir, sincroniza tarefas e atualiza os próximos avisos. A versão web permanece usando o push do navegador descrito acima.

Nos dispositivos móveis, a expansão dos selos preserva as animações e scripts
dos HTMLs originais. Um único controlador WebView ocioso é preparado no perfil
e reaproveitado entre aberturas. A arte só é criada após a expansão do diálogo;
a miniatura fica visível até o carregamento terminar. Os efeitos são pausados
ao fechar o selo ou colocar o app em segundo plano. A textura procedural usa
menos detalhe no mobile, preservando os movimentos, partículas e brilhos.
A opção de reduzir movimento continua sendo respeitada.

Os selos de 50 desafios, Corpo de ferro, Foco inabalável, Leitor assíduo e
Madrugador usam suas próprias artes HTML e miniaturas renderizadas. O primeiro
exige pelo menos 50 desafios concluídos. Os demais exigem a conclusão de
`iron_body`, `digital_fast`, `daily_reading` e `wake_5`, respectivamente.
Todos exibem os efeitos dos HTMLs no mobile e na web, sem concessão manual.

### Confiabilidade e desempenho

As abas são inicializadas na primeira visita e preservam seu estado ao alternar.
As animações das abas ocultas ficam desativadas; início, desafios e progresso do
perfil atualizam os dados ao retornar. Se uma atualização do perfil falhar, os
últimos dados permanecem visíveis, com opção de tentar novamente.

O feed cria os cards conforme entram na área visível. Os horários relativos
compartilham um relógio, ativo apenas enquanto houver cards visíveis. Os
comentários carregam em páginas de 30, dos mais recentes aos mais antigos.

Na rotina autenticada, marcações e desmarcações são persistidas no aparelho
antes do envio. Sem conexão, ficam numa fila separada por conta, e a interface
informa que existem alterações pendentes. A sincronização é tentada ao abrir
ou retomar a rotina/início e pelo botão **Sincronizar**. Leituras offline usam
dados consultados anteriormente; a primeira consulta ainda exige conexão.
Limpar os dados do app remove o cache e as alterações ainda não enviadas.
O resumo semanal consulta os sete dias em uma única requisição.

A migration `20261022000100_challenge_completion_counts.sql` agrega as
conclusões de desafios no banco, restringindo a consulta ao usuário autenticado.
Em ambientes sem essa função, o cliente usa paginação para não truncar o histórico.

O workflow `ci.yml` executa análise, testes e compilações web e Android debug.
O deploy web depende dessa validação. Para verificar localmente:

```powershell
flutter analyze --no-fatal-infos
flutter test
flutter build web --release
flutter build apk --debug
```

Os testes cobrem preservação das abas, paginação, relógio compartilhado,
contagem de históricos extensos e persistência/reenvio offline, incluindo
isolamento entre contas e proteção contra respostas antigas. Reprodução real
do Spotify e fluidez das animações ainda precisam de validação em aparelho.

### Personalização do perfil

Em **Perfil → Editar perfil**, cada membro pode escolher foto, biografia,
capa, moldura, um título conquistado e até três selos para sua vitrine.
A ordem de seleção define a ordem dos destaques; os demais selos continuam
disponíveis na coleção. As escolhas são salvas nos metadados da conta.

As molduras Bronze, Prata e Ouro exigem 1, 10 e 30 desafios concluídos.
A moldura Platina exige a conquista Platina PBH. As capas Constância e
Excelência exigem 1 e 30 desafios, respectivamente. O título de fundador,
a moldura e a capa Legado PBH são exclusivos do líder confirmado; sua foto
padrão é `assets/images/perfil.png`. Títulos de conquistas exigem o selo
correspondente, e a personalização não concede troféus nem permissões.

A migration `20261022000200_profile_avatar_uploads.sql` configura o bucket
`profile-avatars`. Cada conta pode enviar e excluir somente arquivos da
própria pasta; as fotos têm URL pública e limite de 5 MB (PNG, JPEG ou WebP).
O seletor redimensiona a foto para até 1024 pixels. Depois de salvar, a
foto também aparece na comunidade conforme a visibilidade do perfil.
Arquivos substituídos são removidos após salvar os metadados; se esse
salvamento falhar, a foto recém-enviada é removida e a anterior permanece.
As capas são desenhadas no Flutter, e a foto é decodificada com tamanho
limitado para reduzir o custo de renderização no celular.

Também é possível enviar uma capa horizontal própria (PNG, JPEG ou WebP,
até 5 MB), ajustada ao centro da área de capa. A seleção de uma capa do PBH
restaura o visual do projeto; a substituição só é persistida ao salvar.
A migration `20261022000300_profile_cover_uploads.sql` configura o bucket
`profile-covers`, com as mesmas restrições por conta das fotos. O editor
redimensiona capas para até 1600 × 900 pixels e remove uploads substituídos
apenas depois do salvamento bem-sucedido.

As capas do projeto têm brilhos discretos; Legado PBH inclui estrelas
cadentes ocasionais. A moldura da foto tem um brilho que percorre o contorno.
Os efeitos usam pintura isolada no Flutter, sem reconstruir a foto e os textos
a cada quadro. Param quando o cabeçalho sai da tela, outra rota ou aba está
ativa, o app vai para segundo plano ou o sistema solicita reduzir movimento.

Em **Editar perfil**, a animação da moldura e a animação da capa podem ser
selecionadas independentemente das cores e das imagens. As opções da moldura
incluem órbita, pulso, faíscas e anéis; a capa oferece reflexo, estrelas,
meteoros, aurora e brasas. A sobreposição funciona também em capas enviadas.
Cada área permite escolher **Sem animação**. As escolhas ficam salvas com
o perfil. O fundador usa ciano e violeta, com Coroa cósmica e Nebulosa do
fundador exclusivas, mantendo uma aparência diferente das opções Ouro.

### Temas do app e do perfil

Em **Perfil → Aparência do app**, a galeria mostra PBH Original, Meia-noite,
Azul estelar, Vermelho cósmico, Roxo galáctico, Rosa nova e Esmeralda. O líder
confirmado também tem Legado do fundador. A prévia só altera a própria tela
de seleção; **Aplicar tema** atualiza as telas, menus, cards e controles.
O tema de membros é salvo nos metadados da conta (`app_theme`) e em cache
separado por usuário; visitantes têm uma preferência local própria.

Em **Editar perfil → Tema do perfil**, é possível acompanhar a aparência do
app ou escolher outra paleta só para o perfil. Essa escolha é salva em
`profile_style.profile_theme`, independente da capa e das animações.
As telas usam `context.pbhColors`, uma extensão de `ThemeData`, para reagir
às mudanças sem recriar a navegação. Os temas mantêm uma base escura,
texto legível e cores próprias para os conteúdos e artes de conquistas.
