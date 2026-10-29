# Platina no aplicativo nativo

No Android, iOS e web, a Platina PBH e o Rubi do Conhecimento usam
`NativePlatinumArt`. A miniatura do perfil e os detalhes passam pelo mesmo
renderizador Flutter, sem WebView para esses troféus. A preferência de som e
a saída de áudio são preparadas no clique; o som é disparado pelo início da
animação, uma única vez. A web também usa esse caminho para a platina, evitando
dependência de mensagens do iframe e diferenças de tempo entre os troféus.

As camadas `platinum_frame.png` e `platinum_cup.png` foram renderizadas a partir do SVG original de `Trofeu_Platina_PBH.html`, incluindo seus gradientes, textura e brilho. Ambas usam a mesma referência de 600 × 600. O troféu flutua sobre a moldura; feixes, ondas, partículas e revelação são desenhados no Canvas do Flutter. A miniatura usa menos partículas e segmentos, mantendo o mesmo enquadramento.

A revelação tem duração de 5,2 segundos e ocorre uma vez por abertura. As posições das partículas são calculadas pelo tempo, sem depender da quantidade de quadros renderizados. O retorno do app ao primeiro plano não pula a sequência nem repete o som. Os dois relógios param quando o app vai ao fundo, a rota é coberta ou a arte sai da tela. Movimento reduzido apresenta a composição completa sem animação ou som de início.

Os outros troféus conservam seus renderizadores existentes. A reprodução do som
respeita a preferência do usuário e aguarda o primeiro trecho visível do troféu
(aproximadamente 0,58 s), após o carregamento das camadas e a abertura da janela.
O disparo segue o relógio da animação, incluindo suas pausas.

Validação automatizada em `test/native_platinum_art_test.dart`: duas jornadas, tamanhos de 30/160/300 px, ausência de WebView, pausa/retomada, término da revelação, callback único de som e movimento reduzido. A validação visual e de desempenho no celular físico continua necessária. O APK build 46 inclui esta correção.
