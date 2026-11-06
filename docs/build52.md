# Atualização Android 1.0.1 — build 52

Esta atualização reúne as alterações posteriores ao commit `f7e6c14`: alinhamento dos perfis normal e público, menu dos comentários, espaçamentos dos programas, respostas do suporte no sino, atualização isolada de publicações e carregamentos com nova tentativa.

Inclui a opção exclusiva do líder para notificar os membros ao publicar e o visual dos avisos da comunidade: ícone laranja, título “🔥 Post em destaque” e prévia com o nome atual do autor.

## APK

- Arquivo de atualização: `build/releases/PBH-Oficial-v1.0.1-build52-teste.apk`.
- Pacote: `com.amaralstudios.pbh_oficial`.
- Versão: `1.0.1`, código `52` (anterior `51`).
- Mantém a assinatura Android Debug usada no APK de teste anterior, para instalação por cima dessa versão sem desinstalar.
- O script `tools/build-apk.ps1` cria o arquivo de checksum SHA-256 ao lado do APK. APKs e arquivos locais de assinatura não são incluídos no Git.

## Ativação das funções do servidor

O APK não aplica migrações nem faz deploy das funções automaticamente. Conferir as migrações `20261105000600` a `20261105000800` e reimplantar `process-announcement-schedules` e `send-announcement`. Os pré-requisitos e os passos estão em [leader-post-notifications.md](leader-post-notifications.md).

Permitir notificações no celular e manter a conta conectada para cadastrar o aparelho. O botão “Notificar todos os membros” envia para a audiência geral: não é uma prévia exclusiva para o líder. Não foram enviadas notificações reais durante a validação desta atualização.

A moldura das notificações é controlada pelo Android. Instalar este APK fornece os novos ícones e canais; o conteúdo novo depende também da atualização do servidor.
