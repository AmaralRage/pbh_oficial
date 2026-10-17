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

## Dados persistentes

Aplique as migrations em ordem: `20261015000100_profiles_and_initial_admin.sql`, `20261015000200_announcements.sql`, `20261015000300_community_progress.sql`, `20261015000400_admin_notification_center.sql`, `20261017000100_profile_privacy.sql`, `20261017000200_expanded_challenges_and_leader_name.sql` e `20261017000300_community_discovery_moderation.sql`. A migration `20261017000200` adiciona 52 desafios (57 no total). A migration `20261015000400` adiciona segmentação por papel, links de destino, rascunhos e métricas administrativas. A migration `20261017000300` habilita temas, denúncias com motivo, bloqueios e revisão administrativa da comunidade. As políticas RLS limitam alterações à conta autenticada e ao papel de administrador.

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
