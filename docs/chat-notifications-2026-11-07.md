# Notificações das conversas — 07/11/2026

As notificações privadas usam a foto pública e o nome do remetente, com até 240 caracteres de prévia. Uma mensagem de voz aparece como “Mensagem de áudio · 35 s”, “Mensagem de áudio · 1 min 5 s” ou “Mensagem de áudio · 2 min”. Fotos mostram “Foto” e a legenda. Tocar no aviso abre a conversa correspondente.

No Android atualizado, o aviso usa MessagingStyle, com a pessoa como remetente e sua foto como ícone. O sistema define o formato final do cartão. Dispositivos com versões anteriores continuam recebendo o formato compatível até instalarem o novo APK. O registro v3 identifica dispositivos que suportam o novo formato; registros v1/v2 restauram o formato anterior para permitir downgrade.

O worker obtém as prévias por uma função exclusiva de service_role. Perfis privados não expõem identidade pública. A foto aceita apenas o caminho público do próprio usuário no bucket de avatares; o fundador verificado pode usar seu recurso PBH. O app reduz a imagem para 128 px e limita tempo e tamanho de download. Nenhuma chave privilegiada chega ao aplicativo.

Antes e depois de carregar a foto, o app verifica se a conta destinatária continua conectada e com notificações habilitadas. Sair da conta pausa esses avisos e remove somente notificações de chat. O conteúdo da mensagem não é salvo nas preferências locais. A conversa aberta não gera outro alerta em primeiro plano.

Validação: 277 testes Flutter, 16 testes SQL e 16 testes Node passaram. A compilação Android concluiu sem erros. Os testes simulam notificações, fotos e troca de conta; a aparência final e a entrega em segundo plano ainda devem ser conferidas em um celular real com o APK atualizado.

Para conferir: entre com duas contas em aparelhos diferentes, habilite notificações na destinatária, deixe o app em segundo plano e envie texto, foto e áudio. Confira a foto, nome, prévia e duração, depois toque no aviso para abrir a conversa. Nenhum envio real a membros é feito pelos testes automatizados.
