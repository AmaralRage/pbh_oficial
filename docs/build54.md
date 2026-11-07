# APK 1.0.1+54 — 7 de novembro de 2026

Arquivo: `build/releases/PBH-Oficial-v1.0.1-build54-teste.apk`.

SHA-256: `E04D50A471DBB90EB8A913D0185546BE763ECF3C08ADEE28FD2173C24476FFB8`.

Inclui prévias de fotos conforme a tela, seletor de assuntos redesenhado, proteção de reenvio de comentários, opção de baixar a foto original e avanço automático da tela inicial quando existe uma publicação pendente de notificação. O download Android usa `Pictures/PBH` em Android 10+ e seletor de arquivo em versões anteriores.

Compilado em Debug para manter a assinatura dos APKs de teste instalados. A verificação de atualização confirmou pacote `com.amaralstudios.pbh_oficial`, mesmo certificado e versionCode 53 → 54. O APK release continua sendo uma linha de assinatura diferente; nenhuma chave foi alterada.

As duas funções Supabase foram publicadas e confirmadas ativas: `send-announcement` v8 e `process-announcement-schedules` v7. O logo público retornou HTTP 200 como PNG. A migração de comentários já estava presente no remoto; RPC e grants conferidos, sem reaplicar.

Validação: 262 testes Flutter, 13 testes SQL locais e 6 testes Node passaram. Detector de segredos sem ocorrências nos padrões examinados. Compilação `assembleDebug` concluída, assinatura compatível e checksum conferido contra o arquivo `.sha256`.

Não houve envio de notificação real a membros, instalação em aparelho, commit ou push. Imagem gerada na conversa é ilustrativa; o Android controla a apresentação nativa da notificação. O teste físico de recebimento e clique ainda deve ser feito depois da instalação deste APK.
