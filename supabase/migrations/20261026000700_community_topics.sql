-- Acrescenta categorias sem mudar os temas de publicações existentes.
begin;
alter table public.community_posts drop constraint if exists community_posts_topic_check;
alter table public.community_posts add constraint community_posts_topic_check
  check (topic is null or topic in ('disciplina','treino','leitura','proposito','reflexao',
    'duvidas','conquistas','recomendacoes'));
commit;
