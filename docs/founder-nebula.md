# Nebulosa do fundador — três variantes

Em **Perfil → Personalizar perfil → Animação sobre a capa**, selecione
**Nebulosa do fundador**. Abaixo aparecem as três variantes:

- **Nebulosa Imperial:** substitui o efeito antigo; nuvens roxas, ondas azuis e
  ciano, estrelas e brilhos cintilantes.
- **Energia Astral:** cortinas de aurora verticais, arcos de plasma e partículas
  ascendentes em verde, ciano e azul.
- **Eclipse Cósmico:** ondas e nuvens em âmbar, magenta e violeta, com estrelas.

A prévia acompanha a seleção, inclusive na visualização ampliada. A intensidade
continua ajustável. Clique em **Salvar perfil** para manter a escolha. Perfis
antigos com a nebulosa passam a usar a Imperial como padrão. Restaurar a aparência
salva também restaura a variante anterior.

Os desenhos adaptam o arquivo de referência fornecido pelo usuário para Canvas
do Flutter: não incluem o fundo ilustrativo, a cidade, avatar ou selo da demonstração.
A imagem de capa permanece como fundo. A decoração fica recortada na capa,
atrás da foto do perfil e sem interceptar toques. Respeita efeitos reduzidos e
pausa fora da tela. As três variantes são exclusivas do fundador.

## Supabase

Para outros usuários enxergarem a variante escolhida, execute o arquivo completo
`supabase/migrations/20261027000500_founder_nebula_variants.sql` depois das
migrations anteriores. A migration atualiza a função do perfil público e mantém
as verificações de privacidade, bloqueios e exclusividade. Sem ela, o perfil próprio
salva a escolha, mas visitantes recebem a variante padrão.

O APK precisa ser recompilado para incluir estes efeitos. O build 43 anterior
não contém esta alteração.
