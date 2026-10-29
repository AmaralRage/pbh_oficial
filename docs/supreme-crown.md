# Coroa Suprema

Nova moldura `supreme_crown`, separada da Coroa cósmica. Usa a arte embutida em
`moldura_coroa_cosmica_supernova_pbh.html`, com efeitos nativos de partículas,
cometas, arcos, raios e explosões. O retrato fica protegido por recorte central.
A imagem é carregada e seu fundo escuro removido uma única vez em memória.
A moldura tem intensidade ajustável e respeita pausa e movimento reduzido.

## Ativação

Após as migrações anteriores, executar no SQL Editor o arquivo completo
`supabase/migrations/20261028000600_supreme_crown.sql`.

O fundador confirmado já pode selecionar a moldura. No perfil do fundador,
abrir o botão de concessões, selecionar **Coroa Suprema** e informar o e-mail
confirmado do destinatário. A pessoa deve reabrir a personalização do perfil
para carregar a concessão e selecionar a moldura.

A concessão fica em `profile_achievement_awards`, com autor e data. Não é um
troféu e não altera contagens nem requisitos de platina. Para quem não recebeu,
a opção fica ausente de todas as categorias do seletor. O perfil público pode
exibir a moldura de quem a recebeu, mesmo sem compartilhar seu progresso.

Somente o fundador com e-mail confirmado pode chamar a RPC de concessão.
Escritas diretas continuam bloqueadas. A RPC do perfil público consulta a
concessão real e rejeita IDs forjados nos metadados. Contas administrativas
comuns, desafios e platinas não concedem a Coroa Suprema.

Os testes Flutter verificam ocultação, acesso e transparência; os testes SQL
verificam concessão, bloqueio de escrita, metadados forjados e privacidade.
