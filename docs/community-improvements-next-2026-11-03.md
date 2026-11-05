# Busca, edição, atividade e comparação de perfil

## Uso

- **Comunidade → Buscar membros**: pesquisa por nome ou @usuário, com ao menos dois caracteres, debounce e páginas de 30. O resultado abre o perfil público. Não exibe e-mail, data de cadastro ou ID administrativo. Só contas confirmadas aparecem; perfis privados e bloqueios são respeitados. O próprio dono pode encontrar seu perfil privado.
- **Publicação própria → Editar publicação**: texto, anexos e enquadramento na mesma tela. Pode manter, remover ou adicionar fotos, GIFs, vídeos e artes HTML, respeitando os limites existentes de quatro anexos. Enquadrar continua preservando o arquivo original. Quando a quantidade muda entre uma foto e uma grade, o enquadramento é restaurado para evitar distorção.
- **Comunidade → Atividade → Preferências**: controla novas respostas, comentários nas publicações e curtidas, separadamente. Não altera os avisos já recebidos, nem configura push do sistema operacional. Uma curtida por pessoa/publicação gera no máximo um aviso histórico, mesmo se houver descurtida e nova curtida. Responder a um comentário do próprio autor não duplica o aviso para ele.
- **Personalizar perfil → Comparar prévia**: compara as abas **Atual** e **Com alterações**, incluindo background, capa, foto, moldura, tema, transparência e estatísticas. Abrir ou alternar a prévia não salva nada. A aba fora de vista pausa as animações decorativas por TickerMode.

## Banco de dados

Aplicar após as migrations anteriores, nesta ordem:

1. `20261103000600_public_member_search.sql`
2. `20261103000700_unified_post_editor.sql`
3. `20261103000800_community_activity_preferences.sql`

Nenhuma migration foi aplicada no Supabase real pela sessão.

O editor usa caminhos novos com sufixo de revisão. Não sobrescreve arquivos existentes: reserva e envia os novos anexos antes de uma atualização atômica do post. O servidor valida autor, restrição de participação, conteúdo esperado, caminhos, objetos de Storage e enquadramento. Conflitos pedem atualização do feed antes de reabrir o editor. Arquivos removidos e uploads abandonados ficam na fila de limpeza já existente; não são apagados diretamente por SQL. Erros mantêm as escolhas no editor enquanto a tela estiver aberta; não há rascunho persistente de edição após fechar o app.

## Verificação

- Suíte completa: **224 testes Flutter aprovados**.
- Banco local: **14 testes SQL aprovados**. Análise estática sem erros ou avisos; apenas apontamentos informativos de estilo/API.
- Teste SQL integrado: busca por @, nomes iguais, confirmação de conta, perfil privado, bloqueios, anexos ausentes, edição alheia, conflito, preservação dos originais, fila de limpeza, avisos para autor/comentarista, prevenção de duplicação e preferências por conta.
- Testes de interface: falha ao salvar, nova tentativa, remoção de anexo, confirmação ao sair, seleção por nome/@ e ocultação de identificadores administrativos.
- **Nenhum Android conectado ao ADB**. A revisão física de rolagem, teclado, enquadramento e animações permanece pendente. Nenhum APK novo foi solicitado ou gerado nesta etapa.
