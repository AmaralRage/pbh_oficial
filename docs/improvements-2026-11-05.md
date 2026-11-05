# Melhorias de 05/11/2026

As etapas seguintes de atendimento, sessões protegidas, comentários e mídia estão em [improvements-next-2026-11-05.md](improvements-next-2026-11-05.md), incluindo a migração adicional e os resultados de validação.

## O que foi entregue

- Central de atividade com nome e foto atuais do autor, prévia de comentário/publicação, indicação de não lida, paginação de 30 e contador que considera todas as atividades disponíveis. A identidade respeita perfil privado e bloqueios.
- “Marcar todas como lidas” usa o horário da atividade mais recente observada e não marca chegadas posteriores. Ao fechar a central, o contador é atualizado.
- Menções em publicações e comentários: digitar `@` e ao menos duas letras abre sugestões; selecionar insere o identificador, preservando o restante da mensagem. Menções abrem o perfil público disponível no momento do toque. E-mails e identificadores inválidos não são tratados como menções.
- Avisos de menção são gerados no banco, com bloqueios, confirmação de conta, perfil público, preferência do destinatário e prevenção de duplicatas. O usuário pode desativar menções em **Comunidade → Atividade → Preferências**. São avisos dentro do app; nenhuma integração de push nova foi adicionada.
- **Aparência do app → Mais contraste nos cards** reforça o fundo dos cards de vidro sobre backgrounds claros, mantendo textos e artes nítidos. Preferência local ao aparelho; também respeita o alto contraste do sistema. Contraste mínimo de 4,5:1 testado para textos/destaques sobre os fundos reforçados em todos os temas.
- Estatísticas se reorganizam em coluna com texto ampliado ou largura pequena, evitando comprimir os números. O foguinho dos comentários tem área mínima de toque de 48×48. A folha de comentários abre mais alta quando o teclado está visível.
- Diagnóstico administrativo mostra quais funções estão instaladas e quantos arquivos realmente vencidos, não referenciados por posts, aguardam a API de limpeza. Resultados de execução e datas são exibidos em português.

## Banco real: resultado e instalação

Foi realizada uma sondagem **somente de leitura**, pela API e com a configuração pública padrão do app, sem acessar sessões, chaves administrativas ou dados privados:

| Recurso | Resposta em 05/11 |
| --- | --- |
| Perfis públicos | Disponível |
| Busca de membros | Função não encontrada na API |
| Reserva de anexos para edição | Função não encontrada na API |
| Preferências de atividade | Função não encontrada na API |
| Diagnóstico da comunidade | Existe; exige sessão administrativa |

Isso indica pendências de instalação ou de atualização do cache da API. Se o app for iniciado com outro projeto via `--dart-define`, essa configuração deve ser conferida à parte. A sondagem pode ser repetida com `node tools/check-community-backend.mjs`; nenhuma credencial é impressa.

Conferir/aplicar primeiro as migrations anteriores pendentes, nesta ordem:

1. `20261103000600_public_member_search.sql`
2. `20261103000700_unified_post_editor.sql`
3. `20261103000800_community_activity_preferences.sql`

Depois aplicar as novas:

1. `20261105000100_community_activity_details.sql`
2. `20261105000200_community_mentions.sql`
3. `20261105000300_community_readiness_report.sql`

As anteriores dependem das migrations até `20261103000500`. Não repetir migrations já aplicadas. Se as funções existem no SQL Editor, mas a API não as encontra, atualizar o cache com `notify pgrst, 'reload schema';` e repetir a sondagem.

Nenhuma migration foi aplicada pela sessão. A execução real do cron e a remoção de arquivos ainda exigem a consulta em **Admin → Moderação → Diagnóstico da comunidade**, com a conta administrativa. A limpeza de Storage continua usando a API e a fila existentes; esta etapa não criou um worker autônomo de Storage.

## Validação e limites

- Suíte completa: **233 testes Flutter aprovados**, incluindo cenários de teclado, rolagem, sugestões, falha no editor, texto ampliado e contraste.
- Testes adicionais cobrem a atualização imediata do contador após marcar todas como lidas.
- Testes SQL locais cobrem nomes/fotos atuais, privacidade, destinatário, corte temporal, leitura de outra conta, menções sem duplicação e opção de desativar, além do relatório de funções/objetos de Storage.
- ADB não encontrou Android conectado. Portanto, fluidez, áudio e interação em aparelho físico continuam pendentes; as verificações responsivas foram automatizadas. Não foi gerado novo APK nem feito commit/push.
# Complemento: proteção da identidade do fundador

A alteração posterior de segurança está documentada em [private-founder-identity.md](private-founder-identity.md). Aplicar `20261105000400_private_founder_identity_support.sql` antes de distribuir o novo app. Ela fornece a marca de fundador nas sessões e a caixa privada de suporte no Admin. O login e as permissões existentes são preservados.

