# Suporte, sessões, rascunhos e mídia — 05/11/2026

As etapas foram implementadas em sequência, com testes direcionados antes de avançar.

## 1. Atendimento privado completo

- Em **Ajuda e suporte → Falar com o suporte → Meus pedidos e respostas**, o membro consulta os protocolos, o estado do pedido e as respostas da equipe. A lista tem páginas de 30 pedidos e atualização manual.
- No **Admin → Atendimento privado**, a equipe responde sem expor seu e-mail. Pode consultar atendidos e pendentes. Uma resposta que falha no envio permanece no diálogo para tentar novamente.
- O membro pode ler apenas seus pedidos e respectivas respostas. Somente administradores respondem ou marcam como atendido. Essa ação não exclui uma conta.
- Aplicar **primeiro** `20261105000400_private_founder_identity_support.sql` (se ainda não aplicado) e **depois** `20261105000500_private_support_replies.sql`. As migrações não foram executadas remotamente nesta tarefa.
- A resposta é interna, consultada no app; não foi implementado envio de e-mail ou push de suporte.

## 2. Sessões

- **Configurações → Privacidade → Segurança → Sair dos outros aparelhos** encerra a renovação das outras sessões e mantém esta sessão conectada. Tokens já emitidos podem continuar válidos até expirar; não é uma expulsão instantânea de todos os acessos.
- No Android, o Auth usa `flutter_secure_storage` para persistir a sessão com proteção criptográfica da plataforma. Na atualização, a sessão antiga é copiada e conferida antes da remoção da cópia em SharedPreferences. Uma falha não remove a sessão original nem ativa uma alternativa sem proteção. O armazenamento protegido existente tem prioridade sobre uma cópia antiga.
- O backup Android e a transferência dos dados locais foram desativados. Isso também significa que rascunhos locais não são transferidos automaticamente para outro celular. Dados remotos continuam associados à conta.
- Web e demais plataformas mantêm o armazenamento anterior; a migração protegida desta etapa é específica do Android. Não foram alterados login, senha, identidade ou privilégios da conta.
- Referência da biblioteca: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage/versions/10.3.4).

## 3. Rascunhos

- Publicações já tinham rascunhos locais de texto e anexos, com repetição segura pelo mesmo ID. Essa implementação foi preservada.
- Comentários agora salvam texto local por conta e publicação, com gravação após uma pausa curta e ao fechar a aba. Conteúdo vazio remove o rascunho. Textos salvos há mais de sete dias não são recuperados.
- Ao recuperar uma resposta, o app orienta selecionar **Responder** novamente, evitando enviar automaticamente ao destinatário antigo. A publicação é bloqueada se a conta mudar enquanto a aba estiver aberta.
- São rascunhos neste aparelho/navegador, não sincronizados entre dispositivos. A recuperação depende de a gravação local ter concluído; limpar dados/desinstalar remove os rascunhos. A indisponibilidade do armazenamento não impede abrir comentários.

## 4. Envio de mídia

- Publicação e edição mostram quantos anexos terminaram de enviar. É progresso por arquivo concluído, não uma estimativa de bytes ou velocidade. A finalização no banco é exibida separadamente.
- Falhas preservam o texto e os anexos para nova tentativa. Publicações continuam usando o ID do rascunho para evitar duplicação quando a resposta de rede se perde.
- JPGs e PNGs grandes são preparados antes do envio, incluindo os adicionados no editor. A imagem é redimensionada mantendo a proporção, sem recortar. PNG mantém transparência. Há limites de bytes e de resolução para evitar processamentos excessivos.
- GIF, WebP, vídeo e HTML não são achatados em foto estática. Os limites finais do backend permanecem: fotos 5 MB, GIF 10 MB e vídeo 25 MB. Vídeos não são recomprimidos.
- No Android o processamento das fotos é executado via `compute`; no web essa API não garante execução em outra thread.

## 5. Revisão mobile e validação

- ADB não encontrou aparelho conectado. **A revisão prática de fluidez, teclado, consumo de animações e migração da sessão no aparelho ainda está pendente.**
- A compilação Android debug passou, incluindo o plugin de armazenamento protegido e as regras de backup. Esse é um build interno de validação, sem atualização do arquivo de distribuição, da versão ou publicação.
- Testes direcionados passaram para: isolamento de pedidos/respostas no banco; migração segura da sessão; rascunhos por conta/publicação; envio com repetição segura; progresso por arquivo; proporção de fotos; transparência de PNG e preservação de GIF.
- Uma regressão ao construir comentários sem armazenamento disponível foi corrigida, e os dois testes de navegação afetados passaram após a correção.
- Resultado final: **245 testes Flutter passaram**, análise sem erros ou avisos (há sugestões de estilo), teste SQL de privacidade de pedidos/respostas passou, builds **Android debug** e **web release** concluídos.
- O build web padrão em JavaScript passou; o diagnóstico opcional de WebAssembly apontou incompatibilidades em dependências, incluindo `image`. O build Android mostrou avisos de compatibilidade futura de plugins com Kotlin embutido. Esses modos futuros não foram alterados nesta tarefa.

Antes de distribuir, testar em um Android com conta de teste: atualizar uma instalação já conectada, confirmar que a conta continua a mesma, fechar/reabrir comentários com texto, simular falha de rede ao publicar, repetir o envio e conferir que não duplica, enviar/responder um pedido de suporte e encerrar outras sessões.

Não houve commit, push, instalação ou publicação nesta tarefa.

## Complemento: avisos, atualização de publicações e carregamento

Implementado em três etapas, com validação entre elas:

1. **Respostas do suporte no sino:** o contador inclui respostas privadas não lidas. O aviso abre o atendimento com resposta pendente mais recente. Respostas são paginadas, começando pelas mais recentes; somente os IDs carregados são marcados como lidos, respeitando o proprietário. A consulta é renovada a cada 30 segundos com o app ativo e ao retornar ao aplicativo. Não é push de sistema nem envio de e-mail. Administradores que leem um atendimento não limpam o aviso do membro.
2. **Atualização isolada de publicações:** edição de conteúdo, anexos e enquadramento atualiza o card afetado, mantendo a lista, os salvos e os estados de seguir. Mudanças nos comentários atualizam os números sem refazer o feed inteiro. Respostas antigas de consultas concorrentes são descartadas. Se a alteração foi salva, mas a consulta seguinte falhar, o app informa isso e permite tentar atualizar a visualização. Essa atualização corresponde às ações realizadas na própria tela; não foi ativada sincronização em tempo real de todas as edições de outros membros.
3. **Carregamento e conexão:** comunidade, publicações de membros, avisos e suporte usam prévias estáticas de cards e ações de tentar novamente. Conteúdo que já foi carregado é preservado quando a atualização falha. Mensagens ao membro não incluem SQL, nomes de tabelas ou instruções de migração.

**Implantação:** aplicar `supabase/migrations/20261105000600_support_reply_notifications.sql` após as migrações 004 e 005. A migração não foi executada remotamente. Sem ela, os avisos privados do suporte ainda não funcionarão, mas os avisos gerais continuam independentes.

**Validação do complemento:** 251 testes Flutter passaram; análise estática sem erros ou avisos (há sugestões de estilo); teste SQL verificou o isolamento dos avisos e que marcar uma resposta carregada não marca outra que chegou depois. Testes de interface verificaram nova tentativa do suporte, atualização do card sem recarregar a lista, proteção contra resposta antiga da rede, preservação do feed sem conexão e layout com fonte ampliada em tela de 320 px.

Não foi gerado APK, nem realizado commit, push ou publicação neste complemento. No Flutter/VS Code, usar Hot Restart para carregar os novos componentes.

## Publicações com aviso geral do líder

A opção exclusiva **Notificar todos os membros**, com fila protegida no servidor e abertura do post ao tocar no push, está documentada em [leader-post-notifications.md](leader-post-notifications.md). Requer a migração `20261105000700_leader_post_broadcasts.sql` e atualização da função de entrega; esses passos não foram executados remotamente.
