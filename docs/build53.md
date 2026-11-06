# Atualização Android 1.0.1 — build 53

Revisão visual dos avisos do líder: logo PBH, destaque roxo, título **👑 Mensagem do Líder** e prévia com o nome do autor. Na central do aplicativo, os avisos da comunidade têm cartão escuro arredondado e horário no cabeçalho. A moldura e a transparência das notificações do sistema continuam dependendo do Android.

- Arquivo: `build/releases/PBH-Oficial-v1.0.1-build53-teste.apk`.
- Pacote: `com.amaralstudios.pbh_oficial`.
- Versão `1.0.1`, código `53`, usando a assinatura de teste dos builds anteriores.
- Checksum SHA-256 gerado ao lado do APK pelo script de build.

Para ativar o formato novo no servidor, aplicar `20261105000900_leader_message_notification_design.sql` após a 008 e reimplantar `process-announcement-schedules` e `send-announcement`. Veja [leader-post-notifications.md](leader-post-notifications.md). O APK não executa esses passos automaticamente.

A opção “Notificar todos os membros” continua sendo um envio geral. Não foi adicionada uma prévia exclusiva para o líder e não foram enviadas notificações reais durante a validação deste build.
