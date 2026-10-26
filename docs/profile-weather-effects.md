# Animações do perfil

Em **Perfil → Personalizar perfil**, escolha Chuva, Neve ou Vaga-lumes na
moldura da foto e na animação sobre a capa. Cada área tem sua própria intensidade.
O controle aumenta a quantidade de partículas; chuva e neve também ficam mais
rápidas. A intensidade mínima mantém um efeito suave. Para desligar, escolha
**Sem animação**. A prévia no topo acompanha as alterações; toque em **Salvar**
para mantê-las ao reabrir o app.

Os efeitos funcionam sobre capas enviadas pelo usuário. Na foto, ficam limitados
à borda para preservar o rosto. São desenhados pelo Flutter e não usam APIs pagas.
As animações respeitam a redução de movimento do sistema e pausam fora da tela.

Também estão disponíveis **Halloween** (duas abóboras menores nos cantos inferiores,
fumaça roxa e morcegos que aparecem em pontos variados da capa), **Natal** (luzes
coloridas e neve) e **Ano Novo** (fogos coloridos). Os três têm intensidade
ajustável na foto e na capa e podem ser escolhidos durante todo o ano.

Todos os efeitos animados possuem controle de intensidade, inclusive órbita,
pulso, anéis, estrelas, aurora e os exclusivos do fundador. Conforme o efeito,
o ajuste modifica velocidade, brilho ou quantidade de elementos.

## Supabase

Depois das migrations anteriores, execute o conteúdo completo de
`supabase/migrations/20261026001000_profile_weather_effects.sql` no SQL Editor.
Essa migration atualiza a função que entrega o perfil público para permitir os
novos efeitos e suas intensidades. Preserva as verificações de privacidade,
bloqueios e exclusividade do fundador. Não precisa repetir migrations antigas.
Sem essa atualização, o perfil próprio pode mostrar as novas escolhas, mas
visitantes continuarão recebendo os efeitos anteriores.

Para publicar também os efeitos de festas, execute depois o conteúdo completo de
`supabase/migrations/20261026001100_profile_seasonal_effects.sql`.
