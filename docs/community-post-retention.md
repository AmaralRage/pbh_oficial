# Prazo de publicações da comunidade

Execute o arquivo completo `supabase/migrations/20261102000800_community_post_retention.sql` no SQL Editor do Supabase.

- A rotina roda a cada 5 minutos no servidor, mesmo com o app fechado.
- Remove definitivamente publicações com 7 dias ou mais da data original de criação, em lotes de 500.
- Preserva todas as publicações da conta confirmada do líder. Fixar ou editar uma publicação de outro membro não renova o prazo.
- Publicações antigas que já ultrapassaram o prazo ficam elegíveis na primeira execução. Comentários, curtidas, itens salvos e avisos vinculados seguem os relacionamentos `ON DELETE CASCADE` existentes.
- Os gatilhos existentes colocam os caminhos dos anexos na fila de limpeza. Os arquivos físicos são removidos pela Storage API quando o dono ou um administrador acessa a comunidade e a limpeza do app roda. A rotina SQL não apaga diretamente `storage.objects` e, sozinha, não garante liberação imediata do armazenamento.
- A regra só atinge publicações reais; não altera contas, objetivos, selos nem exemplos locais do app.

Para inspecionar o agendamento:

```sql
select jobid,jobname,schedule,active from cron.job
where jobname='pbh-expire-community-member-posts';
```

Para interromper futuras execuções (não restaura posts já removidos):

```sql
select cron.unschedule('pbh-expire-community-member-posts');
```

Para executar manualmente uma rodada no SQL Editor:

```sql
select public.expire_community_member_posts(500);
```

Somente o agendador e o acesso administrativo do banco podem executar a rotina. As contas do app não possuem autorização para dispará-la.
