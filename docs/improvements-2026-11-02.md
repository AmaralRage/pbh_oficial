# Melhorias de comunidade e perfil — 02/11/2026

- Publicações existentes: menu → Ajustar enquadramento das fotos. Altera apenas a prévia; mantém o original no Storage. Conflitos com edições feitas em outro aparelho são rejeitados para evitar sobrescrita silenciosa. Disponível para JPG/PNG/WebP.
- Atividade da comunidade: uma notificação de resposta abre o comentário exato, busca seus ancestrais mesmo fora da primeira página, expande a conversa e destaca a resposta. Continua respeitando bloqueios e visibilidade.
- Admin → Gerenciar selos de membros: lista paginada de concessões, busca por nome/e-mail e remoção diretamente na linha, com confirmação. E-mails dessa lista são retornados apenas para administradores.
- Personalização: seletores independentes para miniaturas do topo e selos em destaque, com prévias e limite de 3 em cada grupo.
- Desempenho: seletores em lista horizontal com construção sob demanda, imagens estáticas decodificadas em até 128×128 e miniaturas estáticas de até 96 px no perfil. HTML e animações de troféus são usados somente na abertura dos detalhes, não em cada miniatura. Capas e molduras mantêm seus controles existentes.

## Supabase

Depois das migrações anteriores, execute o conteúdo completo de:
`supabase/migrations/20261102000600_community_profile_refinements.sql`.

## Validação e limites

Testes automatizados cobrem tela de 320 px com texto ampliado, ausência de animação contínua no seletor, espaço ocupado pelo teclado, resposta antiga fora da página inicial, separação das seleções e permissões dos novos RPCs.

Não há Android conectado. Desempenho, notificações nativas e interação real no aparelho ainda precisam de conferência no celular. Não foi gerado um APK nesta etapa.
