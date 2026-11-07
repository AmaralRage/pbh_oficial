# Qualidade mobile — 7 de novembro de 2026

## 1. Feed e imagens

Antes, cada prévia pedia uma largura fixa de decodificação: 1200 pixels para foto única ou 720 para mosaico, independentemente da tela. Agora usa largura disponível e densidade do aparelho, com intervalos estáveis de 128 pixels e limite de 1600. O enquadramento é considerado pelo tamanho expandido da imagem. Uma `RepaintBoundary` isola a pintura da foto das animações ao redor.

O teste de viewport de 360 pixels e densidade 1 pede 384 pixels na prévia, mantendo o visualizador com a imagem original e `BoxFit.contain`. É uma verificação do tamanho solicitado ao decodificador, não uma medição de memória ou FPS em aparelho. GIFs e HTML continuam seguindo suas regras existentes; cache de decodificação não reduz os bytes originais baixados.

Para medir em aparelho: conectar um Android de entrada, usar `flutter run --profile`, abrir DevTools/Performance e Memory, repetir o mesmo percurso de feed com as mesmas imagens e registrar frames lentos, pico de memória e retorno após sair da tela. Comparar cache frio e quente separadamente. Nenhum Android estava conectado durante esta entrega; não há resultado de desempenho físico a declarar.

## 2. Notificações

Corrigido o clique em push web com uma janela já aberta: agora ela navega para a publicação indicada antes de receber foco. Sem janela, abre o destino. Se a navegação falhar, tenta abrir outra janela. A origem é comparada integralmente e esquemas perigosos são rejeitados. Links HTTPS externos continuam abrindo separadamente.

Testes locais cobrem janela aberta/fechada, destino inseguro, origem semelhante falsa e os testes já existentes de destinatário/navegação nativa. Publicar o build web é necessário para atualizar o service worker. Não foi enviada notificação real a membros.

Validação física pendente: no Android, receber com app aberto, em segundo plano e encerrado normalmente; tocar em cada aviso; confirmar publicação, destinatário e som. Também testar app sem permissão e conta trocada. “Forçar parada” nas configurações do Android é um cenário diferente de apenas fechar o app e precisa ser registrado separadamente.

## 3. Conexão instável

Comentários mantêm um UUID de tentativa por conta/publicação e conteúdo/destino de resposta. Se a resposta HTTP se perder depois do salvamento, a repetição usa o mesmo UUID, inclusive após recriação do serviço. O registro local dura até sete dias, respeita a conta e não publica nada sozinho. A referência só é removida após confirmação e limpeza do rascunho; um novo comentário deliberado recebe outro UUID.

É necessário aplicar **antes do app atualizado**:

`supabase/migrations/20261107000100_idempotent_comment_submissions.sql`

A migração concede apenas INSERT da coluna `id` e expõe um RPC `SECURITY INVOKER`, mantendo RLS e triggers de participação/respostas. Não amplia SELECT nem concede UPDATE. Clientes antigos continuam usando o INSERT anterior; o cliente novo depende do RPC e não faz fallback que possa duplicar comentários.

O teste simula salvamento seguido de resposta perdida, repete o envio e confirma o mesmo UUID. O teste SQL confirma um único registro e bloqueio de escrita por outro membro. Se o comentário foi enviado e apenas a atualização da lista falhar, a mensagem agora distingue essa situação de uma falha de envio. Texto digitado durante a espera não é apagado pela confirmação do comentário anterior.

Rascunhos de publicação, repetição com ID estável de posts, curtidas com estado desejado e recuperação de feed já tinham proteções e foram cobertos pelos testes de regressão. Não foi criada uma fila automática de ações offline. Selecionar outro destino de resposta ou alterar o texto representa uma nova intenção; o usuário deve revisar um rascunho de resposta restaurado antes de reenviar.

## 4. Preparação de distribuição e atualização

O relatório Gradle confirmou que o certificado release configurado difere do certificado debug usado no APK build 53. Um release com essa assinatura não é uma atualização direta dos APKs de teste. Não foram trocadas chaves nem sugerida desinstalação como solução.

`tools/check-apk-update.ps1` compara assinaturas verificadas, pacote e versionCode de dois APKs. Certificados diferentes ou versão não crescente bloqueiam a atualização. A checagem é conservadora: uma futura rotação com signing lineage exige um plano e teste próprios.

`tools/build-apk.ps1` aceita `-PreviousApk`. Para release, a referência é obrigatória e a compatibilidade é validada antes da cópia para `build/releases`. Para teste/debug, a referência é opcional, mas recomendada. Exemplo para uma próxima atualização de teste, **não executado nesta entrega**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-apk.ps1 -Mode Debug -BuildNumber 54 -PreviousApk build/releases/PBH-Oficial-v1.0.1-build53-teste.apk
```

Testes do verificador: APK debug 52 → 53 aprovado; comparação com APK de outro certificado bloqueada. O script não instala, não remove e não publica apps.

Antes da distribuição pública, decidir e testar uma estratégia de migração da base debug para a assinatura definitiva e guardar a chave de distribuição e sua recuperação em local seguro. Preservar a linha de teste atual enquanto essa estratégia não estiver validada. A versão no `pubspec.yaml` permanece 1.0.1+53; nenhuma versão nova foi entregue nesta etapa.

## Evidências

- 257 testes Flutter passaram na suíte completa; testes dirigidos de prévia, rascunho/reenvio e navegação também passaram.
- 13 testes SQL locais de permissões, privacidade e repetição de comentários passaram.
- Testes Node de worker, apresentação e clique de push passaram.
- Análise Flutter sem erros ou warnings; há avisos informativos de lint existentes no projeto.
- Sem aparelho conectado: testes físicos de FPS/memória, recebimento real de push e instalação sobre a versão atual continuam pendentes.
- Sem aplicação remota da nova migração, commit, push ou novo APK nesta entrega.
