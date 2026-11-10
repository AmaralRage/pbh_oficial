begin;
-- Extend only the theme allowlist, retaining the deployed profile/privacy rules.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.community_member_profile(uuid)'::regprocedure);
 if position('''graphite_classic''' in definition)=0 then
  if position('''emerald_classic''' in definition)=0 then
   raise exception 'A lista de temas clássicos deve estar aplicada antes do tema Grafite.';
  end if;
  execute replace(definition,'''emerald_classic''','''emerald_classic'', ''graphite_classic''');
 end if;
end $$;
commit;
