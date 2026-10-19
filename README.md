# PBH Oficial

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

## Dados persistentes

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

Depois de publicar o site em HTTPS, cada pessoa ativa “Notificações no navegador” em Perfil > Configurações > Notificações. A Edge Function verifica o papel de administrador e o público selecionado antes de enviar os avisos. A taxa de envio representa notificações aceitas pelo serviço push do navegador; a taxa de leitura vem das confirmações registradas dentro do app. O agendamento ainda depende de configurar uma rotina no Supabase; enquanto isso, a central publica imediatamente ou salva como rascunho.

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
