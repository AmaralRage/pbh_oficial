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
