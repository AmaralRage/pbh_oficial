# Identidade privada do fundador

O novo app não contém o endereço pessoal do fundador em `lib`, `web` ou `assets`. O login continua usando o mesmo e-mail e senha. Não é necessário criar outra conta, e não há mudanças de ID, conquistas, papel administrativo ou dados do perfil.

## Ordem de implantação

1. Aplicar `supabase/migrations/20261105000400_private_founder_identity_support.sql` no SQL Editor do projeto Supabase. A migração depende do Auth e de `public.is_admin()` já existentes. Executar uma vez, como as demais migrações.
2. Publicar a nova versão web/APK somente depois. Na abertura conectada, sessões antigas sem a marca são renovadas antes da aplicação do tema. Entrar novamente também recebe a marca. Se a renovação falhar por falta de rede, a sessão não é descartada pelo app; recursos visuais exclusivos podem ficar indisponíveis até a renovação.
3. Conferir a conta do fundador, o tema exclusivo e o painel Admin. Em uma conta comum, conferir que os recursos exclusivos não aparecem.
4. Enviar uma mensagem em Configurações → Ajuda e suporte → Falar com o suporte e verificar Admin → Atendimento privado. Testar também a solicitação de exclusão com uma conta de teste. Marcar um pedido como atendido não exclui a conta; o processamento permanece manual.

A migração não foi executada remotamente nesta alteração. O app novo depende dela; sem ela, a identificação exclusiva e o envio ao suporte não estarão disponíveis. Não houve build de APK nem publicação.

## Proteções

- A marca booleana `pbh_project_leader` fica em `auth.users.raw_app_meta_data`, controlada pelo servidor. Dados editáveis do perfil (`user_metadata`) são ignorados para essa identificação.
- Um trigger atribui a marca pela regra privada existente e a recalcula quando o e-mail, a confirmação ou os metadados administrativos mudam. A marca é preenchida nas contas existentes, preservando os demais metadados.
- As verificações de autorização do banco continuam no servidor; o booleano do app serve para apresentar as funcionalidades corretas e não substitui RLS ou controles administrativos.
- Ajuda e exclusão de conta usam pedidos internos. Somente administradores podem ler e marcar pedidos como atendidos. Membros não leem pedidos alheios nem fornecem o ID do remetente; o servidor usa `auth.uid()`. Há limite de 20 pedidos por conta a cada 24 horas.
- Complemento posterior: com `20261105000500_private_support_replies.sql`, o membro também pode consultar seus próprios pedidos e as respostas da equipe. Pedidos alheios continuam bloqueados. Veja [suporte e melhorias seguintes](improvements-next-2026-11-05.md).
- O pedido é associado ao UUID da conta, sem copiar automaticamente e-mails para mensagens. A mensagem é texto simples. O membro é orientado a não enviar senhas ou códigos.

## Limitações

A regra privada ainda contém o endereço no SQL do servidor para preservar a autorização existente. Não distribuímos essas migrações como assets Flutter. Quem tiver acesso ao repositório ou ao painel do banco ainda poderá ler a regra. Retirar o endereço do histórico do Git, de versões antigas ou de caches publicados exige ações adicionais e não foi feito aqui. Isso reduz exposição futura no aplicativo, mas não torna secreto um endereço já divulgado.

Validação local: **237 testes Flutter passaram**; análise sem erros ou avisos (há sugestões de estilo existentes); teste SQL de preenchimento/revalidação da marca, tentativa de falsificação, controle de leitura/escrita de pedidos e limite diário passou. Inclui testes de renovação da sessão, conquistas, temas e envio sem inclusão de e-mails. Nenhuma senha ou segredo foi impresso nos testes.
