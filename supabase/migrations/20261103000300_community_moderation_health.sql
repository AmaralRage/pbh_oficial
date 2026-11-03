begin;
create table public.community_restrictions(
 user_id uuid primary key references auth.users(id) on delete cascade,
 until_at timestamptz not null,
 granted_by uuid references auth.users(id) on delete set null
);
alter table public.community_restrictions enable row level security;
revoke all on public.community_restrictions from public,anon,authenticated;
create function public.guard_community_participation() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.community_restrictions where user_id=new.user_id and until_at>now()) then
 raise exception 'Sua participação na comunidade está temporariamente restrita.' using errcode='42501'; end if;
 return new;
end $$;
revoke all on function public.guard_community_participation() from public,anon,authenticated;
create trigger guard_community_post before insert on public.community_posts for each row execute function public.guard_community_participation();
create trigger guard_community_comment before insert on public.community_comments for each row execute function public.guard_community_participation();
create function public.admin_restrict_community_member(p_post uuid,p_days integer) returns void
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
 if not coalesce(public.is_admin(),false) then raise exception 'Admin access required' using errcode='42501'; end if;
 if p_days is null or p_days not between 0 and 30 then raise exception 'Duração inválida.'; end if;
 select user_id into recipient from public.community_posts where id=p_post;
 if recipient is null then raise exception 'Publicação indisponível.'; end if;
 if exists(select 1 from public.profiles where id=recipient and role='admin') or
 exists(select 1 from auth.users where id=recipient and lower(email)='amaralaragao31@gmail.com' and email_confirmed_at is not null) then
 raise exception 'Este membro não pode ser restringido.' using errcode='42501'; end if;
 if p_days=0 then delete from public.community_restrictions where user_id=recipient;
 else insert into public.community_restrictions values(recipient,now()+make_interval(days=>p_days),auth.uid())
 on conflict(user_id) do update set until_at=excluded.until_at,granted_by=excluded.granted_by; end if;
end $$;
revoke all on function public.admin_restrict_community_member(uuid,integer) from public,anon;
grant execute on function public.admin_restrict_community_member(uuid,integer) to authenticated;

create function public.admin_clear_community_restriction(p_user uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(public.is_admin(),false) then raise exception 'Admin access required' using errcode='42501'; end if;
 delete from public.community_restrictions where user_id=p_user;
end $$;
revoke all on function public.admin_clear_community_restriction(uuid) from public,anon;
grant execute on function public.admin_clear_community_restriction(uuid) to authenticated;

create function public.admin_community_health() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; job jsonb;
begin
 if not coalesce(public.is_admin(),false) then raise exception 'Admin access required' using errcode='42501'; end if;
 select jsonb_build_object('expired_posts',count(*)) into result from public.community_posts p
 where p.created_at<=now()-interval '7 days' and not exists(select 1 from auth.users u where u.id=p.user_id and lower(coalesce(u.email,''))='amaralaragao31@gmail.com' and u.email_confirmed_at is not null);
 result:=result||jsonb_build_object('pending_media',(select count(*) from public.community_photo_cleanup));
 result:=result||jsonb_build_object('restrictions',coalesce((select jsonb_agg(to_jsonb(r)) from (
 select c.user_id,c.until_at,left(coalesce(nullif(u.raw_user_meta_data->>'display_name',''),p.display_name,'Membro'),40) as name
 from public.community_restrictions c join auth.users u on u.id=c.user_id left join public.profiles p on p.id=c.user_id
 where c.until_at>now() order by c.until_at limit 50) r),'[]'::jsonb));
 if to_regclass('cron.job') is not null then
 execute $q$select jsonb_build_object('scheduled',j.active,'schedule',j.schedule,'last_status',r.status,'last_run',r.end_time)
 from cron.job j left join lateral(select status,end_time from cron.job_run_details where jobid=j.jobid order by runid desc limit 1) r on true
 where j.jobname='pbh-expire-community-member-posts' limit 1$q$ into job;
 end if;
 return result||coalesce(job,'{"scheduled":false}'::jsonb);
end $$;
revoke all on function public.admin_community_health() from public,anon;
grant execute on function public.admin_community_health() to authenticated;
commit;
