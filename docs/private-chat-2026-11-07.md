# Conversas privadas — 07/11/2026

O cabeçalho tem acesso a **Conversas**, com contador de mensagens não lidas. A lista permite buscar conversas existentes ou iniciar uma nova buscando nome ou @usuário exclusivo. O perfil público de outro membro tem o botão **Conversar**.

## Recursos

- Conversas individuais com texto, uma foto por mensagem, respostas e exclusão das próprias mensagens para ambos os participantes.
- Mensagens de voz de até dois minutos e 1 MB. O microfone aparece quando o campo está vazio e vira envio ao digitar ou anexar foto. A gravação permite parar, ouvir, descartar e enviar.
- Atualização por Realtime, paginação do histórico e recuperação ao retornar ao app.
- Confirmação de leitura e notificação privada que abre a conversa correspondente.
- Rascunho local preservado quando o envio falha. O mesmo identificador é reutilizado para confirmar um envio cuja resposta se perdeu, evitando duplicatas.
- Papel de parede por conversa, salvo somente neste aparelho e separado por conta. Ele não é enviado ao outro membro nem ao Storage.
- Prévia do papel de parede com controle de escurecimento de 0% a 85%, inclusive para ajustar uma imagem já escolhida pelo menu da conversa.
- Avatares consultam a identidade pública verificada, incluindo a foto padrão do fundador quando não houver uma foto enviada.
- Cores acompanham o tema do aplicativo. O avatar no cabeçalho abre o perfil do membro.

## Privacidade e armazenamento

Somente os dois participantes autenticados podem consultar mensagens e anexos. Bloqueios da comunidade também impedem acesso à conversa. Clientes não têm permissão para inserir ou modificar diretamente as tabelas: as operações passam por funções com validação de identidade.

As mensagens expiram individualmente **sete dias após o envio**. Elas deixam de aparecer nas consultas assim que expiram. Uma tarefa executada a cada minuto remove até 1.000 mensagens expiradas e aciona a fila de remoção de fotos e áudios pela Storage API. Falhas no worker deixam o anexo na fila para nova tentativa; os metadados de Storage não são apagados por SQL. Backups ou arquivos já salvos por um participante não são apagados por essa rotina.

Fotos ficam no bucket privado `chat-photos`, sem URLs públicas permanentes. O app redimensiona e comprime as imagens para JPEG de até 512 KB e 1.280 pixels no maior lado, removendo EXIF. URLs assinadas duram 60 segundos; uma URL emitida antes de expiração ou bloqueio pode continuar válida até terminar esse prazo.

Há limites de 30 mensagens por minuto por remetente, 20 novas conversas por dia e cinco anexos pendentes por conta. Esses limites e a retenção reduzem o consumo, mas não substituem o acompanhamento de uso do Supabase.

Este chat usa as proteções de acesso do Supabase e transporte HTTPS; **não implementa criptografia de ponta a ponta**. Os administradores com acesso privilegiado ao banco podem tecnicamente consultar seu conteúdo. Rascunhos ficam no armazenamento interno do app ou IndexedDB do navegador, sem uma camada adicional de criptografia criada por este recurso.

Notificações mostram o nome, a foto pública e uma prévia da mensagem do remetente. Áudios mostram “Mensagem de áudio” e a duração; fotos mostram “Foto” e a legenda, quando houver. O worker seleciona dispositivos e assinaturas somente do destinatário, verifica novamente sua titularidade antes de enviar e registra recibos privados para reduzir reenvios. As permissões do celular e a configuração de notificações continuam necessárias. Veja [a implementação e os testes](chat-notifications-2026-11-07.md).

## Backend ativado

Foram aplicados os arquivos `20261107000200_private_chat.sql` e `20261107000300_chat_retention_delivery.sql` no projeto vinculado, sem aplicar outras migrações pendentes. A função `process-private-chat` foi publicada. Ela exige o segredo privado do agendador já existente; nenhuma chave privilegiada foi adicionada ao aplicativo.

Conferido no projeto: RLS nas cinco tabelas, negação de INSERT direto por clientes, negação de acesso anônimo, bucket privado, publicação Realtime e tarefa de limpeza ativa. Chamada externa ao worker sem credencial retornou HTTP 401.

## Como validar no aplicativo

Validações realizadas após o suporte a áudio: 272 testes Flutter, 15 testes SQL de segurança e 12 testes Node passaram. A compilação Flutter Web e a verificação de compilação Android concluíram com sucesso. O scanner de credenciais não encontrou chaves privilegiadas nos arquivos examinados. As sondagens anônimas das cinco tabelas do chat foram negadas com HTTP 401/código 42501, sem baixar registros.

1. Reinicie o app pelo Flutter/VS Code para carregar as novas telas.
2. Com duas contas de teste, abra **Conversas → Nova conversa** e localize a outra conta pelo nome ou @usuário.
3. Envie texto, foto e uma resposta usando o menu de pressionar a mensagem. Confira o recebimento e a leitura na outra conta.
4. Ative notificações na conta destinatária, coloque o app em segundo plano e envie outra mensagem. Ao tocar no aviso, ele deve abrir a conversa.
5. Troque o papel de parede no menu da conversa. Ele deve mudar somente neste aparelho.
6. Desconecte a rede, tente enviar e reconecte: o rascunho deve continuar disponível para tentar novamente, sem duplicar a mesma tentativa.

Os testes automatizados usam contas fictícias e serviços simulados. Eles não substituem a conferência com dois aparelhos reais, principalmente para notificações em segundo plano. Este trabalho não gera nem publica um novo APK automaticamente.
