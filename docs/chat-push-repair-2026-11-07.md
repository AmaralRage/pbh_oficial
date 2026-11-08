# Correção da entrega do chat — 07/11/2026

## Causa confirmada no remoto

A tabela `native_push_tokens` não tinha a coluna `sound_enabled`, prevista na migração `20261027000200_device_notification_sound.sql`. As funções de registro v2/v3 existiam e dependiam dessa coluna. Por isso o registro atualizado falhava e o worker também falhava ao consultar os dispositivos. A permissão Android ligada não corrigia essa inconsistência do banco.

Foram observados apenas metadados operacionais: nenhum registro v3 recente, ausência de recibos e tentativas esgotadas. O teste privado, sem envio, falhou em `device_lookup`. A consulta ao catálogo confirmou a ausência da coluna. Não foram expostos textos, identidades, e-mails ou tokens nas saídas dos diagnósticos.

## Reparo

`20261107000800_repair_native_push_sound.sql` restaura a coluna de forma idempotente e solicita atualização do cache da API. Tokens e seus donos são preservados. O cadastro completo volta a funcionar quando o app retorna ao primeiro plano ou quando as notificações são ativadas novamente.

`20261107000700_chat_push_diagnostics.sql` adiciona um código operacional privado às tentativas. O worker guarda apenas códigos conhecidos, sem copiar respostas brutas ou dados das mensagens. Um diagnóstico protegido pelo segredo do cron usa `validate_only:true` do FCM: não entrega notificações nem cria mensagens.

Após o reparo, o mesmo diagnóstico completou as consultas e recebeu `200 / VALID` do Firebase. Isso confirma estrutura, acesso, autenticação e formato; o recebimento físico continua dependendo de um novo teste no celular.

## Verificação

- O teste SQL reproduz a coluna ausente e a falha do registro v3, aplica o reparo duas vezes e confirma o registro, inclusive som desabilitado e troca de dono da instalação.
- Os 16 cenários SQL e oito testes direcionados de worker/apresentação passaram. O TypeScript do worker foi verificado.
- Não foi gerado novo APK: o build 55 já contém o código necessário. Não foram reenviadas em massa notificações antigas nem criadas mensagens de teste para membros.

Para conferir no aparelho: feche e abra o PBH, deixe a conta destinatária em segundo plano e envie uma nova mensagem de outra conta. Se necessário, desative e ative “Receber notificações” dentro do PBH para forçar um novo registro. Uma conversa que permanece aberta e marca a mensagem como lida pode suprimir o alerta por comportamento previsto.
