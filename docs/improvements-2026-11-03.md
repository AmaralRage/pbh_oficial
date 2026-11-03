# Comunidade e perfis — 03/11/2026

## O que mudou

- Curtidas atualizam somente a publicação alterada, preservando o restante do feed e sua paginação. A ordem e as estatísticas gerais são renovadas ao atualizar o feed.
- Prévias de imagens usam decodificação limitada a 1200 px de largura (720 px nas grades); o visualizador continua usando o original. Selos em miniatura continuam estáticos.
- Notificações destacam respostas não lidas, descartam IDs repetidos e limpam o estado na troca de conta. O acesso ao comentário de destino continua usando seu contexto e ancestrais.
- Identificador `@usuário` exclusivo, independente do nome público. O identificador fica oculto no card: passar o mouse sobre o nome mostra uma tag; tocar no nome abre o identificador e a opção de copiar. No próprio perfil, esse menu também permite editar o @usuário. Contas recebem um identificador inicial derivado do UUID, sem colisões. Formato: 3–40 caracteres, letras ASCII minúsculas, números e sublinhado, começando por letra.
- Busca administrativa aceita nome, @usuário ou ID. O UUID continua sendo a referência usada para conceder selos; nomes iguais não confundem a concessão.
- “Ver publicações” no perfil público e “Minhas publicações” no perfil próprio, em páginas de 20. A consulta no servidor verifica visibilidade do perfil e bloqueios. São as publicações existentes do feed; não há arquivo de posts expirados.
- Moderação abre o post completo, incluindo anexos. Administradores podem restringir novas publicações e comentários por sete dias, após confirmação. Líder e administradores são protegidos contra essa restrição. A expiração é automática; liberação antecipada fica no diagnóstico.
- Diagnóstico em **Admin → Moderação da comunidade → ícone de monitoramento**: agendamento, resultado/horário da última execução, posts vencidos, lotes de anexos pendentes e restrições ativas. O botão de anexos processa a fila pela API de Storage e atualiza os números; falhas continuam pendentes para nova tentativa.

## Instalação no Supabase

Aplicar nesta ordem, após as migrations anteriores:

1. `20261103000100_member_handles.sql`
2. `20261103000200_member_publications.sql`
3. `20261103000300_community_moderation_health.sql`

Não foram aplicadas no banco de produção por esta sessão. O diagnóstico verifica o cron existente da migration `20261102000800`; não cria um segundo agendamento nem executa exclusões extras. Sem acesso conectado ao Supabase não é possível confirmar a execução real desse cron. A exclusão de objetos de Storage continua dependendo do processamento da fila pela API, durante o acesso à comunidade ou pelo botão administrativo; não há worker de Storage autônomo novo.

## Verificação

- Suíte completa: **208 testes Flutter aprovados**. Banco local: **11 testes SQL aprovados**, incluindo as novas migrations.
- Análise estática: nenhum erro ou aviso; 335 apontamentos informativos de estilo/API no projeto.

- Teste SQL integrado cobre unicidade/normalização de nomes, permissões, nomes repetidos, busca por @, perfil privado, bloqueios, restrição de posts/comentários, proteção do líder e diagnóstico com/sem cron.
- Testes Flutter cobrem edição do @usuário com conflito, consulta paginada de publicações mantendo originais, limites de decodificação das prévias e enquadramento.
- O teste de enquadramento passou a aguardar o botão habilitado, em vez de pressupor que a decodificação sempre termina em 50 ms.
- Desempenho percebido, áudio e fluidez ainda precisam de validação em aparelho físico. Nenhum APK, commit ou push foi solicitado nesta etapa.

- Ajuste posterior da tag: seis testes direcionados aprovados, incluindo mouse, toque, edição e navegação do perfil.

## Cards transparentes opcionais

Personalizar perfil > Background > Cards transparentes ativa preenchimento translúcido (52%) e desfoque de fundo de 5 px, limitado aos contornos dos cards de identidade, objetivo e estatísticas. Apenas o fundo muda: não se aplica Opacity ou ImageFiltered ao conteúdo; capas, molduras, selos e troféus permanecem nítidos. Opção desativada por padrão, sem animação contínua.

Aplicar também `20261103000400_profile_glass_cards.sql` para disponibilizar a preferência nos perfis públicos. Validação: 28 testes Flutter direcionados e teste SQL de persistência e privacidade aprovados.

## Variantes Clássico e alcance do tema

Aparência do app oferece versões Clássico de Meia-noite, Azul estelar, Vermelho cósmico, Roxo galáctico, Rosa nova e Esmeralda, mantendo as versões coloridas. O fundador e o PBH Original já usam fundos neutros.

A opção Aplicar no app inteiro salva o alcance por conta e sincroniza em metadados; desligada, o app usa PBH Original e o perfil recebe o tema escolhido. Ao ligar, o perfil passa a acompanhar o tema do app. As outras personalizações são preservadas. Aplicar `20261103000500_classic_profile_themes.sql` para permitir os novos IDs no perfil público.

20 testes Flutter de aparência/contraste e o teste SQL dos temas clássicos aprovados. Removido texto acidental `xzs` da declaração `public_style` na migration 004 antes de reutilizar a função na 005.
