# Melhorias do chat — 07/11/2026

## Comportamento

- **Digitando:** aparece no cabeçalho enquanto o outro participante escreve. O app atualiza o estado no máximo uma vez a cada três segundos e o estado expira em seis segundos. Enviar, apagar o texto ou sair da conversa encerra o indicador. Nenhuma letra digitada é enviada com esse estado.
- **Áudios:** a barra permite avançar depois de carregar o áudio. O botão alterna entre 1×, 1,5× e 2×. Permanecem os limites de dois minutos, 1 MB e exclusão após sete dias.
- **Resposta:** arrastar uma mensagem para a direita seleciona a resposta, sem excluir a mensagem. O menu de toque longo continua disponível. A área de composição mostra a mensagem original; contextos fora da página atual são consultados com as mesmas permissões do chat.
- **Silenciamento:** menu da conversa → Silenciar conversa. A preferência pertence à conta e à conversa e vale no servidor para todos os dispositivos. As mensagens continuam chegando. O usuário pode reativar os avisos pelo mesmo menu. O worker verifica a preferência antes do envio, inclusive para mensagens já na fila. Um aviso entregue antes do silenciamento já pertence ao sistema do celular.
- **Busca:** menu da conversa → Buscar na conversa. Pesquise a partir de dois caracteres; resultados são paginados e respeitam a retenção de sete dias. Tocar num resultado prepara uma resposta àquela mensagem.

## Segurança e armazenamento

`20261107000600_chat_experience.sql` cria estados de digitação e preferências com RLS. Somente participantes têm acesso à digitação e somente o dono lê suas preferências. Busca e contexto usam as políticas das mensagens existentes, incluindo bloqueios e expiração. A consulta de autorização das notificações é exclusiva de service_role.

Os estados de digitação têm uma linha por participante e conversa, expiração curta e limpeza a cada cinco minutos. Nenhum texto ou áudio é duplicado para implementar essas funções. As preferências locais guardam apenas o estado de silenciamento, separado por conta e conversa, para suprimir avisos que já estavam em trânsito no próprio aparelho.

## Validação

Passaram 281 testes Flutter, 16 cenários SQL e 17 testes Node. Foram verificados gesto de resposta, prévia original, busca vazia/com resultado, duração temporária do indicador, ativação/desativação de avisos e velocidades de áudio. Os testes SQL cobrem participante externo, escrita direta negada, preferências de outro usuário, bloqueios, mensagens expiradas e autorização de notificações. O worker também tem teste que confirma ausência de envio quando a entrega é negada.

## Conferência em dois celulares

1. Instale o build 55 sobre o anterior, entre com contas diferentes e habilite notificações nas duas.
2. Digite na conta A com a conversa aberta na B; confira “digitando…” e seu desaparecimento ao parar/apagar/enviar.
3. Envie texto, foto e áudio. Arraste uma mensagem, confira a prévia e responda. Ouça o áudio nas três velocidades e avance pela barra.
4. Procure uma palavra da conversa e toque no resultado para responder. Uma palavra ausente deve mostrar o estado vazio.
5. Silencie a conversa na B e deixe o app em segundo plano. Uma nova mensagem deve chegar à conversa sem alerta. Reative os avisos e repita.
6. Com avisos ativos, confira foto, nome e prévia; áudio deve mostrar sua duração. Toque no aviso com o app em segundo plano e depois repita com ele fechado: deve abrir a conversa correta.
7. Saia da conta e confira que avisos antigos de chat foram removidos. Entre na outra conta e confirme que nenhum novo aviso da conta anterior aparece.

Esses passos físicos ficam para a instalação do usuário. Não houve envio de mensagens reais nem teste em dois aparelhos por automação.
