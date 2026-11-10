# Usabilidade do chat — 09/11/2026

As melhorias foram implementadas e verificadas em etapas, sem mudança de esquema ou nova função remota.

1. **Prévia de fotos:** depois da galeria, uma tela permite ampliar a imagem, revisar a legenda e confirmar em “Enviar foto”. Voltar cancela a seleção e preserva o rascunho anterior.
2. **Reenvio:** uma tentativa sem confirmação aparece na conversa com o conteúdo e “Tentar novamente”. A nova tentativa conserva o mesmo UUID e aproveita a verificação idempotente do serviço. Texto, foto e áudio permanecem no rascunho protegido, separado por conta/conversa, com um indicador persistido de tentativa pendente. Editar o conteúdo passa a ser uma nova tentativa com outro identificador.
3. **Voltar ao fim:** ao subir no histórico aparece um botão. Mensagens recebidas enquanto a pessoa está acima do fim são contadas sem forçar a rolagem. Ao retornar, o contador é limpo e a leitura é confirmada.
4. **Mensagens novas:** na primeira carga, o número de não lidas fornecido pelo servidor determina a faixa inicial. A faixa permanece no mesmo ponto durante a visita, mesmo depois de o servidor confirmar a leitura. Se o início das não lidas estiver numa página anterior, a faixa aparece ao carregar essa página.
5. **Acessibilidade:** controles de áudio e retorno têm áreas de toque de 48 px; a ação de responder também está disponível à tecnologia assistiva. O cabeçalho se ajusta à escala de texto, estados de leitura têm descrição em português e o contraste do botão de envio acompanha a luminosidade da cor do tema. O retorno ao fim respeita a preferência por movimento reduzido.

Os testes direcionados simulam cancelamento/confirmação da foto, perda de resposta e reenvio com o mesmo UUID, persistência da tentativa, chegada de mensagens durante leitura do histórico, retorno ao fim, permanência da faixa de não lidas e texto em escala 1,8× numa tela de 320 px. Não houve envio a membros durante os testes.

As alterações ficam no código; não foi gerado novo APK ou feito commit/push nesta etapa.
