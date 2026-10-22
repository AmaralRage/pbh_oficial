# Investigação da autorização Spotify no Android

## Evidência local

- APK examinado: `build/app/outputs/flutter-apk/app-debug.apk`, versionCode 23.
- Pacote real, extraído com aapt: `com.amaralstudios.pbh_oficial`.
- targetSdk real: 36. O aparelho informado usa Android 15.
- SHA-1 do certificado **do APK**, verificado com apksigner:
  `2F:E3:93:94:75:04:3C:D0:E0:1E:2F:55:94:D3:ED:1F:D6:79:8E:5B`.
- O SHA-1 corresponde ao que foi solicitado para cadastro no Dashboard.
  O usuário informou depois que a seção Android estava vazia e a preencheu.
  A captura enviada confirmou o pacote e o SHA-1 corretos após o preenchimento.
- O usuário confirmou que a conta no navegador e no Spotify é a mesma.
- Sem dispositivo conectado via adb; não há logcat que confirme a falha exata.

## Incompatibilidade encontrada e corrigida

O bytecode do AAR oficial App Remote 0.8.0, incluído neste projeto, foi inspecionado
com javap. `SpotifyServiceBinder.bindToService` chama
`context.getApplicationContext().bindService(intent, connection, 65)`.
65 contém `BIND_AUTO_CREATE | BIND_IMPORTANT`, mas não
`BIND_ALLOW_ACTIVITY_STARTS` (512), necessário desde Android 14 para permitir
que um serviço vinculado apresente uma Activity de autorização.

`SpotifyAuthorizationContext` preserva o contexto da aplicação e acrescenta
essa opção apenas no vínculo ao serviço de protocolo oficial do Spotify,
quando a conexão solicita explicitamente autorização. Atualizações silenciosas
e outros serviços não recebem a opção. Nenhuma permissão especial é pedida ao
usuário e o AAR não é modificado.

O erro após uma tentativa explícita agora é `AUTH_NOT_RECOGNIZED`, distinguindo
autorização não reconhecida de autorização ainda não solicitada. Não se afirma
que o usuário recusou a permissão.

## Limites da conclusão

A incompatibilidade de vínculo é verificável localmente. A ausência do cadastro
Android no Dashboard foi confirmada pelo usuário e explica a falha de validação
da identidade do APK mesmo após o consentimento. Os dados foram preenchidos e
comparados com a assinatura real. A reprodução no aparelho ainda não foi
verificada por telemetria ou logcat; não confundir testes locais com teste real.

Última entrega: APK debug build 25, com 47 testes Flutter aprovados na validação
do código que ele contém. O usuário confirmou as configurações e encerrou a sessão.

## Fontes

- Android: https://developer.android.com/about/versions/14/behavior-changes-14
- Relato de falha de abertura de autorização: https://github.com/spotify/android-sdk/issues/377
- Relato de mensagem enganosa com fingerprint incorreto: https://github.com/spotify/android-sdk/issues/384
