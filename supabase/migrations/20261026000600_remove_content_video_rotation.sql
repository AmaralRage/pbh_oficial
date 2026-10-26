-- Cancelamento da rotação automática. Pode rodar mesmo sem a instalação antiga.
-- Mantém o catálogo, os vídeos publicados e o progresso dos alunos.
begin;
do $$
declare scheduled_job bigint;
begin
  if to_regclass('cron.job') is not null then
    for scheduled_job in select jobid from cron.job where jobname='pbh-content-video-rotation' loop
      perform cron.unschedule(scheduled_job);
    end loop;
  end if;
  if to_regclass('public.content_programs') is not null then
    drop trigger if exists content_video_rotation_after_insert on public.content_programs;
  end if;
  if to_regclass('vault.secrets') is not null then
    delete from vault.secrets where name in ('pbh_content_project_url','pbh_content_cron_secret');
  end if;
end $$;

drop function if exists public.run_content_video_scheduler();
drop function if exists public.claim_content_video_rotation();
drop function if exists public.finish_content_video_rotation(text,uuid,jsonb,text,jsonb,text);
drop function if exists public.admin_configure_content_rotation(text,boolean,text);
drop function if exists public.admin_review_content_video(uuid,boolean);
drop function if exists public.admin_restore_content_media(uuid);
drop function if exists public.initialize_content_video_rotation();

drop table if exists public.content_media_history;
drop table if exists public.content_video_suggestions;
drop table if exists public.content_video_rotation;
commit;
