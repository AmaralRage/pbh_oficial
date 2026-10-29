# Rubi do Conhecimento e vitrine do perfil

O troféu final dos cinco desafios do Conhecimento passa a ser **Rubi do
Conhecimento**, com a arte de `Trofeu_Rubi_PBH_Animado.html`. A Jornada Original
continua concedendo a Platina PBH. O identificador persistido
`knowledge_platinum` foi preservado para manter progresso, desbloqueios de
cosméticos e celebrações já registradas. Não é necessária migração SQL.

A arte de rubi é renderizada por camadas nativas no Flutter, inclusive na web,
com cores próprias, flutuação, partículas e sequência de desbloqueio. Assim ela
usa o mesmo controle de visibilidade, ciclo de vida e movimento reduzido do
troféu de platina corrigido para celular. O som começa pelo callback da animação.

O perfil apresenta a platina e o rubi quando conquistados, seguidos de até três
outras conquistas escolhidas em **Personalizar perfil → Selos**. A seleção usa
o campo `featured` existente e mantém a ordem escolhida. Quem prefere somente
os dois troféus pode desmarcar as outras conquistas. As miniaturas adaptam o
tamanho à largura disponível e podem quebrar linha em telas muito estreitas.

As regras existentes de perfil público e compartilhamento de conquistas
continuam valendo. Não são exibidas conquistas que a pessoa não possui.
