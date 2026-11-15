# PBH Oficial 1.0 Beta 2 — build 58

Data: 14 de novembro de 2026.

Versão técnica: `1.0.0-beta.2+58`. Mantém a apresentação pública **1.0 Beta**.

## Alterações

- Notificações privadas associadas a atalhos de conversa do Android, com avatar
  do remetente. Funciona também no engine em segundo plano; o Android controla
  a aparência final. Limitações do sistema não impedem a entrega normal.
- Balões compactos, horários e confirmação dentro do balão, datas discretas e
  botão de anexo dentro do campo de mensagem. Cores seguem o tema do usuário.
- Tamanho das letras no menu da conversa, com prévia, cinco tamanhos e restauração
  do padrão. Preferência local por conta e conversa, sem alterar o aparelho do destinatário.
- Fotos preservam a proporção sem recorte quadrado, limitadas a 240 de largura e
  300 de altura; o visualizador continua permitindo ampliação.
- No navegador, processamento da imagem passa para as APIs nativas de imagem e
  canvas, evitando a compressão Dart na thread da interface. No Android, mantém
  o processamento em isolate. Indicador de preparo e proteção contra seleção duplicada.

## Backend e instalação

Nenhuma migration nem republicação de função Supabase é necessária para estas
alterações. É necessário instalar o novo APK para testar as notificações Android.
A validação automatizada não substitui a conferência visual no aparelho.

## Validação

- 303 testes Flutter aprovados, incluindo tamanho das letras, proporção das
  imagens, envio/reenvio, prévia e notificações privadas.
- Análise estática sem erros ou avisos; permanecem sugestões informativas.
- Verificação de segredos no código e histórico: 716 arquivos e 1392 blobs
  históricos verificados, sem ocorrências.

O APK usa a assinatura de teste da build 57 para permitir atualização sem
desinstalar a versão anterior. Artefatos ficam em `build/releases`, fora do Git.

APK: `build/releases/PBH-Oficial-v1.0.0-beta.2-build58-teste.apk`.

Compatibilidade confirmada: pacote `com.amaralstudios.pbh_oficial`, versionCode
57 → 58 e mesmo certificado.

SHA-256: `52CB5BE742A57C1D9335915FD210BA69F414AC9225D16A4F6E5AAC98244B48FD`.
