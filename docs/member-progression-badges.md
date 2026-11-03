# Selos de progresso e busca de membros

Execute `supabase/migrations/20261102000700_progression_member_badges.sql` depois das migrações anteriores.

## Regras automáticas

- Iniciante: 5 tarefas de rotina concluídas, somando os registros existentes de `habit_completions`.
- Constante: 90 dias distintos com pelo menos uma tarefa de rotina concluída. Várias tarefas no mesmo dia contam como um dia; não exige sequência sem faltas. Datas futuras não contam.
- Veterano: 1 ano civil desde a criação da conta (`auth.users.created_at`). A condição é calculada na leitura, sem cron ou serviço pago.

Os registros anteriores à instalação contam. O app atualiza as identidades ao reabrir a tela e periodicamente enquanto visíveis.

## Concessão manual

O líder confirmado pode conceder ou remover antecipações de Iniciante, Constante e Veterano. Administradores continuam gerenciando Guardião, Mentor e Embaixador. A validação ocorre no banco, inclusive para a antiga chamada por e-mail.

Somente o maior selo aplicável aparece junto ao nome, nesta ordem: Guardião, Mentor, Embaixador, Veterano, Constante, Iniciante, Membro. O fundador mantém Líder. Remover a concessão manual não revoga um selo conquistado automaticamente. Selos não concedem poderes administrativos.

## Busca

Admin → Gerenciar selos de membros → Pesquisar e escolher membro. A seleção usa o ID da conta; não exige e-mail. A busca aceita nome ou parte do ID, mostra foto e data de entrada para diferenciar nomes iguais e pagina os resultados de 30 em 30. Apenas administradores e o líder podem consultar essa lista.
