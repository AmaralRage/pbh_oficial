# Notificações de conversa no Android

As notificações do chat já usavam MessagingStyle e Person com a foto do remetente.
Faltava publicar um atalho de conversa de longa duração e associá-lo à notificação.
O Android pode usar essa associação para destacar o avatar à esquerda, com a
identificação do PBH, em vez de tratar a foto apenas como imagem à direita.

O plugin local pbh_conversations registra-se automaticamente em todos os engines,
inclusive no engine em segundo plano do Firebase. Android 11 ou posterior publica
o atalho com nome, avatar e identidade do remetente. O destino reaproveita o payload
de navegação validado por conta; o conteúdo da mensagem não é salvo no atalho.

Os identificadores incluem conta e conversa. Ao limpar notificações/sair da conta,
os atalhos dinâmicos e os de longa duração registrados são removidos. O cache de
identidades fica limitado a 64 entradas. Falhas ou limitações do Android preservam
a entrega normal da mensagem. Sem foto, há uma inicial como alternativa.

Não altera Supabase, permissões de envio, texto nem preferências de som. Requer
um novo APK instalado para testar no aparelho. O fabricante e a versão do Android
controlam a aparência final; não há garantia de reprodução idêntica ao WhatsApp.

Referência: https://developer.android.com/develop/ui/views/notifications/conversations
