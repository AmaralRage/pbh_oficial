-- Acrescenta referências em português sem substituir mídias já editadas.
-- Não altera IDs, textos ou o histórico de conclusão das aulas.
begin;
with sources as (
  select key as program_id, value as data
  from jsonb_each($media${"fundamentos_homem_valor":{"lesson_ids":["valores","rotina_minima","ambiente","revisao"],"media":{"title":"Como superar paradigmas que protegem e limitam sua vida","author":"Gino Terentim • TEDxESMPU","summary":"Uma reflexão sobre escolhas automáticas e mudanças de comportamento. Assista pensando em um padrão da sua rotina que gostaria de revisar.","url":"https://www.ted.com/talks/gino_terentim_como_superar_paradigmas_que_protegem_e_limitam_sua_vida","kind":"video","thumbnail_url":"https://pi.tedcdn.com/r/talkstar-photos.s3.amazonaws.com/uploads/5ab03e2d-5cad-4066-9c10-8981a163ac4c/mqdefault.jpg"}},"lideranca_silenciosa":{"lesson_ids":["ouvir","comunicar","compromissos","feedback"],"media":{"title":"Liderança além do cargo","author":"Janaina Faria Fidelis Borges • Sebrae Play","summary":"Uma conversa sobre influência e conexão com a equipe. Relacione o vídeo aos compromissos e às conversas que fazem parte do seu dia.","url":"https://www.sebraeplay.com.br/content/lideranca-alem-do-cargo","kind":"video","thumbnail_url":"https://files.lms.file.spalla.io/files/da6e4543190f76043a2c-Capa%20Conte%C3%BAdos%20Sebrae%20Play.jpg"}},"estoicismo_pratico":{"lesson_ids":["escolhas","pausa","imprevistos","reflexao"],"media":{"title":"Autocontrole & Estoicismo #1 — Dicotomia do Controle","author":"Ivan Biava • Papo Estoico","summary":"O episódio aborda como distinguir as próprias ações dos acontecimentos externos. Use essa reflexão para escolher uma resposta possível a um imprevisto.","url":"https://www.youtube.com/watch?v=Q083fq9MxQQ","kind":"podcast","thumbnail_url":"https://i.ytimg.com/vi/Q083fq9MxQQ/hqdefault.jpg","audio_url":"https://open.spotify.com/episode/7hGWMo7xWxEv0ZtGZRCXeh"}},"corpo_combate":{"lesson_ids":["objetivo","preparar","registro","equilibrio"],"media":{"title":"Sente dores no corpo? Pode ser o sedentarismo!","author":"Drauzio Varella • Portal Drauzio","summary":"Um vídeo sobre movimento e limites do corpo. Relacione o tema à organização da sua rotina de atividades.","url":"https://www.youtube.com/watch?v=y4pOpbdYIpY","kind":"video","thumbnail_url":"https://i.ytimg.com/vi/y4pOpbdYIpY/hqdefault.jpg"}}}$media$::jsonb)
)
update public.content_programs p set curriculum = (
  select jsonb_agg(jsonb_set(m.value, '{lessons}', (
    select coalesce(jsonb_agg(
      case when (s.data->'lesson_ids') ? (l.value->>'id')
        and coalesce(l.value->'media', 'null'::jsonb) = 'null'::jsonb
        then l.value || jsonb_build_object('media', s.data->'media')
        else l.value end
      order by l.position), '[]'::jsonb)
    from jsonb_array_elements(m.value->'lessons') with ordinality as l(value, position)
  )) order by m.position)
  from jsonb_array_elements(p.curriculum) with ordinality as m(value, position)
)
from sources s where p.id = s.program_id and jsonb_array_length(p.curriculum) > 0;
commit;
