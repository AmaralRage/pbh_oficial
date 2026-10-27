# Melhorias de confiabilidade e distribuição — 27/10/2026

## 1. Anotações e datas das aulas

As anotações continuam privadas e separadas por conta. Entrando na mesma conta
em outro aparelho, elas são carregadas do Supabase. Há cópia local para uso sem
conexão; a tentativa de envio ocorre ao salvar ou reabrir a anotação. A interface
indica sincronização pendente. Notas antigas deste aparelho são enviadas ao serem
abertas; nenhuma nota de visitante é transferida silenciosamente para uma conta.

Edições concorrentes usam revisões: se outro aparelho já alterou a nota, o texto
local é preservado e a interface oferece abrir a versão da conta, com confirmação.
Copie os trechos que deseja manter antes de substituir o campo. Essa substituição
também deixa uma cópia de segurança local do rascunho.

As datas conhecidas das conclusões são sincronizadas; prevalece a primeira data.
Conclusões antigas sem data continuam sem data, sem gerar registros fictícios.

## 2. Notificações

Os avisos administrativos enviados ao Android respeitam o som escolhido para
aquele dispositivo. A preferência é enviada com o registro do token e atualizada
nas configurações. Falhas de conexão deixam uma mensagem para nova tentativa.
Ao voltar ao app, o cadastro é sincronizado novamente. Desativar notificações
também cancela os lembretes locais agendados; novos agendamentos respeitam essa
desativação. Os agendamentos de rotina consultam a preferência de som ao serem
criados ou atualizados.

**Validação física pendente:** nenhum aparelho estava conectado ao executar as
verificações. Em um Android real, testar primeira permissão, recusa, segundo plano,
processo encerrado normalmente, som desligado, desativação, troca de conta e logout.
Não confundir entrega aceita pelo FCM com recebimento comprovado no aparelho.

## 3. Legibilidade

O tema dos chips agora resolve a cor por estado depois da combinação de estilos.
Os testes conferem textos efetivamente renderizados nas oito paletas, com fonte
dobrada e opções selecionadas, normais e desabilitadas.

## 4. Conquistas

Troféus mostram a regra de nível, os dias restantes e a data real de desbloqueio
quando o histórico permite identificá-la. A data é o dia em que se atingiu a
quantidade exigida de registros, não a data da consulta. O fundador e registros
antigos sem histórico não recebem datas inventadas. Selos concedidos, selos de
dedicação e conquistas de desafios têm orientações distintas.

## 5. Efeitos reduzidos e desempenho

Em **Aparência do app → Efeitos reduzidos**, ative o modo estático. A preferência
fica no dispositivo e soma-se à redução de movimento do sistema. As decorações
param e os detalhes dos troféus usam imagens, evitando WebViews nessa modalidade.
Fora desse modo, animações continuam pausando fora da tela ou em abas inativas.

Para medir em um celular conectado, execute `flutter run --profile -d ID_DO_APARELHO`.
No DevTools, grave a mesma sequência com os efeitos ligados e reduzidos: rolar o
perfil por 30 segundos, abrir e fechar um troféu 10 vezes e alternar abas.
Compare duração de frames e memória após cada sequência. Só declare resultados
de desempenho do celular depois dessa medição; testes de widgets não a substituem.

## 6. APK e assinatura

Versão do app: **1.0.1+42**. O nome mostrado no Android continua **PBH Oficial**.
Para gerar arquivos com nome identificável:

```powershell
.\tools\build-apk.ps1 -Mode Debug
.\tools\build-apk.ps1 -Mode Release
```

Saída em `build/releases/`:

- `PBH-Oficial-v1.0.1-build42-teste.apk`: atualização da versão de teste existente.
- `PBH-Oficial-v1.0.1-build42.apk`: distribuição, com chave própria.
- Cada APK recebe um arquivo `.sha256` para conferir sua integridade.

A chave local fica em `android/pbh-distribution.jks`; as credenciais ficam em
`android/key.properties`. Ambos são ignorados pelo Git. Faça backup seguro dos
dois fora deste computador: a mesma chave é necessária nas próximas atualizações.
O arquivo `android/key.properties.example` contém somente o modelo sem segredos.
Builds release não usam mais assinatura de debug como alternativa silenciosa.

**As assinaturas são diferentes:** um APK de distribuição não substitui o de
teste instalado. Use o APK `-teste` para manter a instalação atual. Para distribuir,
use a nova assinatura desde a primeira instalação. Integrações que validam o
certificado, como o Spotify nativo, exigem cadastrar o SHA-1 da nova assinatura no
respectivo painel antes de validar a versão release. Não copie chaves privadas
para esses painéis.
O SHA-1 e os demais dados públicos do certificado estão em
`build/releases/PBH-Oficial-certificado-publico.txt`.

## Ativação no Supabase

Execute os arquivos completos, um de cada vez, depois das migrations anteriores:

1. `supabase/migrations/20261027000100_learning_sync.sql`
2. `supabase/migrations/20261027000200_device_notification_sound.sql`
3. `supabase/migrations/20261027000300_challenge_achievement_dates.sql`

Depois da segunda migration, publique as funções `send-announcement` e
`process-announcement-schedules` com o arquivo compartilhado `native-push.ts`
atualizado. A mudança de som dos avisos remotos depende dessa publicação.
Os arquivos foram preparados e testados localmente; isso não aplica alterações
automaticamente ao projeto Supabase remoto.

## Resultado da validação local

- 127 testes da suíte Flutter passaram, além do novo teste de sincronização entre
  dispositivos (128 testes ao todo). Os ajustes finais de textos também passaram
  na execução direcionada dos testes de notas e conquistas.
- Cinco testes de backend passaram: quatro de envio/som e um cobrindo as três
  migrations novas, privacidade e conflitos de notas.
- O analisador não apontou erros nem warnings; permanecem lints informativos.
- Ambos os APKs 1.0.1 build42 foram compilados e tiveram assinatura e SHA-256
  conferidos. A assinatura de distribuição é distinta da assinatura de teste.
- Testes no celular e medição de desempenho físico foram adiados por escolha do
  usuário. Não foram substituídos por uma alegação de entrega ou desempenho real.

Validações locais:

```powershell
flutter test
flutter analyze --no-fatal-infos
npx --offline --yes deno test --cached-only --allow-read --allow-env supabase/tests/learning_sync_test.ts
npx --offline --yes deno test --cached-only --allow-env supabase/functions/_shared/native-push_test.ts
```
