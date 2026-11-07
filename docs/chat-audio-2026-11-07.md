# Mensagens de voz — 07/11/2026

## Uso

No chat, o botão mostra um microfone quando o campo está vazio. Ao digitar texto ou anexar uma foto, ele muda para envio. Tocar no microfone solicita a permissão somente nesse momento e abre a gravação.

A gravação para automaticamente antes de ultrapassar dois minutos, deixando uma pequena margem para a última amostra do encoder. É possível parar antes, ouvir, descartar ou enviar. O áudio não é enviado automaticamente ao atingir o limite. Se o envio falhar, a gravação fica no rascunho local para tentar novamente com o mesmo identificador.

Na conversa, os áudios têm reprodução por toque e controle de posição. Não há download ou reprodução automática. Apenas um áudio toca por vez e a reprodução pausa ao colocar o aplicativo em segundo plano.

## Armazenamento e acesso

- Captura mono a 32 kbps: AAC/M4A no Android e Opus/WebM no Chrome. A seleção depende do suporte disponível no aparelho ou navegador.
- Limite de 1 MB por arquivo, bucket privado `chat-audio` e caminhos vinculados ao remetente, à conversa e à mensagem.
- O servidor lê o arquivo e valida a duração e a estrutura do contêiner. A duração informada pelo cliente não autoriza o envio.
- `validate-chat-audio` autentica a conta e verifica a titularidade da reserva. Somente o serviço pode registrar a validação no banco. O RPC de envio exige essa validação.
- As políticas de leitura exigem participação na conversa, ausência de bloqueio e mensagem não expirada. Não são criadas URLs públicas.
- O cache de reprodução fica somente na memória, limitado a 8 MB por instância do serviço e separado por conta. Cada reprodução reconsulta a visibilidade da mensagem, inclusive ao usar bytes já baixados.
- A mensagem e o arquivo expiram após sete dias. O worker existente remove os arquivos usando a Storage API e mantém na fila qualquer remoção que falhar.
- Arquivos temporários da gravação são removidos após a leitura. Rascunhos de envios incertos são locais e continuam separados por conta e conversa.

As mesmas limitações de privacidade do chat continuam válidas: o recurso não implementa criptografia de ponta a ponta e a exclusão não remove cópias já baixadas nem backups históricos.

## Implementação e ativação

Aplicada a migração `20261107000400_private_chat_audio.sql` no projeto vinculado. Publicadas as funções `validate-chat-audio` e `process-private-chat`. A limpeza usa o agendamento existente, sem criar um segundo processo de retenção.

O Android declara `RECORD_AUDIO`; o iOS declara a finalidade do uso do microfone. O pacote de gravação atual exige `web` 1.x; por isso o pacote de compartilhamento também foi atualizado para uma versão compatível. As atribuições de `srcdoc` das capas e selos foram adaptadas ao tipo JavaScript exigido pela API web atual, preservando o sandbox dos iframes.

Foram testados: isolamento com três contas fictícias, rejeição de áudio acima de dois minutos, limite de tamanho, validação restrita ao servidor, retenção e fila de limpeza, reenvio sem duplicação, cache com nova checagem de acesso, recusa de permissão e parada automática da gravação. Um teste de integração no Chrome gravou um microfone sintético e submeteu os bytes ao mesmo parser do servidor, sem enviar mensagens reais.

Resultado final: 272 testes Flutter, 15 testes SQL e 12 testes Node passaram; compilação web e tarefa Android `:app:compileDebugKotlin` concluídas. No projeto remoto foram conferidos o bucket privado limitado a 1 MB, as políticas de acesso e a tarefa de limpeza ativa. A função publicada de validação recusou chamada sem autenticação com HTTP 401.

## Conferência manual

1. Encerre e inicie novamente o Flutter após atualizar as dependências; hot reload não registra sozinho um plugin nativo novo.
2. Abra uma conversa com outra conta, toque no microfone e permita o acesso.
3. Grave uma mensagem curta, pare, ouça a prévia e envie. Confira reprodução e resposta na outra conta.
4. Digite no campo vazio: o microfone deve mudar para envio. Apagar o texto deve restaurar o microfone.
5. Teste cancelar e negar a permissão: nada deve ser enviado.
6. No Android, é necessário instalar uma nova compilação do APK para ter o gravador. Os testes com microfone sintético não substituem uma conferência em aparelho real.

Nenhum novo APK de distribuição é gerado ou publicado por essa alteração.
