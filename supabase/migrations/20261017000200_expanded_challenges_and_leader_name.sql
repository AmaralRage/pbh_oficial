-- Expand the challenge catalog and standardize the project leader display name.
insert into public.challenge_catalog (id, title, description, total_days, level, icon_key) values  ('7day_focus', 'Foco por 7 dias', 'Uma semana para reduzir distrações e cumprir suas prioridades.', 7, 'iniciante', 'flag'),
  ('phone_free_morning', 'Manhã sem celular', 'Comece o dia longe das notificações e com intenção.', 7, 'iniciante', 'phone'),
  ('walk_daily', 'Caminhada diária', 'Inclua movimento leve todos os dias.', 14, 'iniciante', 'fitness'),
  ('water_habit', 'Hidratação consciente', 'Crie uma rotina consistente de hidratação.', 14, 'iniciante', 'flag'),
  ('gratitude_journal', 'Diário de gratidão', 'Registre diariamente algo pelo qual você é grato.', 14, 'iniciante', 'book'),
  ('bedtime_routine', 'Rotina de sono', 'Prepare corpo e mente para dormir no mesmo horário.', 21, 'iniciante', 'sunrise'),
  ('20min_reading', '20 minutos de leitura', 'Leia um pouco todos os dias e avance com constância.', 21, 'iniciante', 'book'),
  ('no_sugar_week', 'Uma semana sem açúcar', 'Observe seus hábitos e reduza o açúcar adicionado.', 7, 'intermediario', 'fitness'),
  ('cold_shower', 'Banho consciente', 'Finalize o banho com alguns instantes de água fria.', 14, 'intermediario', 'flag'),
  ('early_riser', 'Acordar cedo', 'Levante no horário planejado e proteja sua manhã.', 21, 'intermediario', 'sunrise'),
  ('daily_meditation', 'Meditação diária', 'Reserve alguns minutos para respirar e recuperar o foco.', 21, 'iniciante', 'flag'),
  ('tidy_space', 'Ambiente em ordem', 'Dedique alguns minutos por dia para organizar seu espaço.', 14, 'iniciante', 'flag'),
  ('no_social_morning', 'Manhã sem redes sociais', 'Adie as redes sociais e comece o dia com propósito.', 14, 'intermediario', 'phone'),
  ('pushup_progress', 'Progressão de flexões', 'Treine flexões com técnica e progressão gradual.', 30, 'intermediario', 'fitness'),
  ('run_beginner', 'Corrida para iniciantes', 'Construa resistência com sessões progressivas.', 30, 'iniciante', 'fitness'),
  ('core_strength', 'Força do core', 'Pratique exercícios para estabilidade e força central.', 21, 'intermediario', 'fitness'),
  ('mobility_daily', 'Mobilidade diária', 'Cuide da mobilidade com uma rotina breve.', 21, 'iniciante', 'fitness'),
  ('no_alcohol', 'Pausa no álcool', 'Experimente um período sem bebidas alcoólicas.', 30, 'avancado', 'flag'),
  ('budget_month', 'Mês de orçamento', 'Registre gastos e acompanhe seu orçamento diariamente.', 30, 'intermediario', 'book'),
  ('learn_language', 'Estudo de idioma', 'Pratique um novo idioma todos os dias.', 30, 'iniciante', 'book'),
  ('write_daily', 'Escrita diária', 'Escreva algumas linhas para organizar pensamentos e ideias.', 21, 'iniciante', 'book'),
  ('one_task', 'Uma prioridade por dia', 'Conclua uma tarefa importante antes de dispersar sua atenção.', 30, 'intermediario', 'flag'),
  ('no_complaints', 'Sem reclamações', 'Troque reclamações por ações construtivas durante a jornada.', 14, 'intermediario', 'flag'),
  ('kindness_daily', 'Gentileza intencional', 'Faça uma ação gentil e consciente por dia.', 21, 'iniciante', 'flag'),
  ('call_family', 'Presença com a família', 'Separe tempo diário para se conectar com quem importa.', 14, 'iniciante', 'flag'),
  ('cook_at_home', 'Cozinhar em casa', 'Prepare refeições em casa com planejamento simples.', 21, 'iniciante', 'fitness'),
  ('protein_breakfast', 'Café da manhã nutritivo', 'Construa uma rotina matinal com escolhas nutritivas.', 14, 'iniciante', 'fitness'),
  ('stretch_breaks', 'Pausas para alongar', 'Faça pausas curtas para alongamento durante o dia.', 21, 'iniciante', 'fitness'),
  ('weekly_planning', 'Planejamento semanal', 'Planeje prioridades e revise seu progresso por semana.', 28, 'intermediario', 'book'),
  ('focus_blocks', 'Blocos de foco', 'Trabalhe em períodos concentrados com pausas planejadas.', 21, 'intermediario', 'flag'),
  ('no_impulse_buy', 'Compras conscientes', 'Evite compras por impulso e registre suas escolhas.', 30, 'intermediario', 'book'),
  ('donate_weekly', 'Generosidade semanal', 'Pratique uma ação de generosidade a cada semana.', 28, 'iniciante', 'flag'),
  ('service_month', 'Mês de serviço', 'Contribua com sua comunidade de forma consistente.', 30, 'intermediario', 'flag'),
  ('lead_by_example', 'Liderar pelo exemplo', 'Pratique diariamente os valores que deseja inspirar.', 30, 'avancado', 'flag'),
  ('public_speaking', 'Prática de comunicação', 'Desenvolva confiança ao se expressar com clareza.', 21, 'intermediario', 'book'),
  ('conflict_reflection', 'Reflexão após conflitos', 'Reserve um momento para aprender com conversas difíceis.', 14, 'intermediario', 'book'),
  ('digital_sunset', 'Pôr do sol digital', 'Desconecte-se das telas antes do horário de dormir.', 21, 'intermediario', 'phone'),
  ('weekend_outdoors', 'Fim de semana ao ar livre', 'Passe tempo ao ar livre e recarregue sua energia.', 28, 'iniciante', 'fitness'),
  ('cycling_month', 'Ciclismo constante', 'Pedale com regularidade e aumente o percurso gradualmente.', 30, 'intermediario', 'fitness'),
  ('swimming_routine', 'Natação consistente', 'Construa uma rotina de natação com progressão segura.', 30, 'intermediario', 'fitness'),
  ('bodyweight_month', 'Treino com peso corporal', 'Mantenha uma rotina progressiva usando o peso do corpo.', 30, 'intermediario', 'fitness'),
  ('no_takeout', 'Cozinha planejada', 'Planeje refeições e reduza pedidos por conveniência.', 21, 'intermediario', 'fitness'),
  ('content_fast', 'Pausa de conteúdo', 'Reduza o consumo passivo de conteúdo digital.', 14, 'intermediario', 'phone'),
  ('morning_pages', 'Páginas matinais', 'Escreva pela manhã para clarear ideias e intenções.', 30, 'iniciante', 'book'),
  ('purpose_review', 'Revisão de propósito', 'Reflita diariamente sobre valores e direção de vida.', 21, 'intermediario', 'book'),
  ('financial_learning', 'Educação financeira', 'Estude finanças pessoais um pouco todos os dias.', 30, 'iniciante', 'book'),
  ('gratitude_letters', 'Cartas de agradecimento', 'Expresse gratidão por escrito a pessoas importantes.', 14, 'iniciante', 'book'),
  ('consistent_prayer', 'Momento de oração', 'Reserve um momento diário para oração ou reflexão espiritual.', 30, 'iniciante', 'flag'),
  ('volunteer_month', 'Voluntariado consistente', 'Dedique tempo para servir e apoiar outras pessoas.', 30, 'intermediario', 'flag'),
  ('creative_practice', 'Prática criativa', 'Dedique alguns minutos diários a uma habilidade criativa.', 30, 'iniciante', 'book'),
  ('no_snooze', 'Levantar sem soneca', 'Levante no horário escolhido sem adiar o despertador.', 21, 'intermediario', 'sunrise'),
  ('five_minute_rule', 'Regra dos cinco minutos', 'Comece tarefas importantes com cinco minutos de ação focada.', 21, 'iniciante', 'flag')
on conflict (id) do nothing;

update public.profiles
set display_name = 'Amaral'
where lower(email) = 'amaralaragao31@gmail.com';
create or replace function public.sync_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, role, display_name)
  values (
    new.id,
    coalesce(new.email, ''),
    case
      when lower(coalesce(new.email, '')) = 'amaralaragao31@gmail.com'
       and new.email_confirmed_at is not null then 'admin'
      else 'member'
    end,
    case
      when lower(coalesce(new.email, '')) = 'amaralaragao31@gmail.com' then 'Amaral'
      else nullif(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '')
    end
  )
  on conflict (id) do update
    set email = excluded.email,
        role = excluded.role,
        display_name = coalesce(excluded.display_name, public.profiles.display_name);
  return new;
end;
$$;