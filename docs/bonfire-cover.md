# Fogueira das Almas

Em **Perfil → Personalizar perfil → Capa do perfil**, escolha **Fogueira das
Almas**. A seleção ativa o efeito **Brasas** e uma base escura. O efeito segue a
versão aprimorada do HTML: fogueira vetorial com pedras, lenha, espada e três
camadas de chamas no canto inferior direito, com brasas espalhadas pela capa,
brilho difuso e rastros. As partículas são mais densas perto da fogueira.
A intensidade controla quantidade e velocidade. Salve o perfil para manter a escolha.

A espada fica fixa; as chamas, a iluminação e as partículas se movimentam.
A decoração permanece dentro da capa, atrás da
foto do perfil e sem interceptar toques. Efeitos reduzidos mantêm a arte estática.

Selecionar a animação **Brasas** preserva uma capa pessoal enviada e desenha a
fogueira vetorial por cima dela. Não inclui a paisagem da versão anterior.

Para que visitantes recebam o novo estilo de capa, execute o arquivo completo
`supabase/migrations/20261027000600_bonfire_cover.sql` após as migrations anteriores,
incluindo `20261027000500_founder_nebula_variants.sql`. A atualização mantém
as variantes da nebulosa e as verificações de privacidade e exclusividade.

O APK precisa ser recompilado para incluir a imagem e o novo efeito.
