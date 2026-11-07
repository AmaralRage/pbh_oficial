# Revisão de segurança — 7 de novembro de 2026

Não foi encontrada chave administrativa no frontend examinado. A configuração Flutter usa `sb_publishable_`, que identifica o projeto e depende das permissões do banco para autorizar acesso. Chaves `sb_secret_` e JWT `service_role` não devem aparecer no app: ignoram RLS. Referência: [documentação oficial do Supabase](https://supabase.com/docs/guides/database/secure-data).

## Verificações realizadas

- Busca em 615 arquivos versionados e 1.213 blobs do histórico Git alcançável: nenhuma correspondência para chaves `sb_secret_`, JWT com papel `service_role`, cabeçalhos de chave privada ou IDs de acesso AWS nos conteúdos de texto. Binários são ignorados; os padrões não reconhecem todos os tipos de credencial nem histórico remoto inacessível. Não é uma certificação de ausência de segredos.
- Revisão da configuração Flutter, pipeline web, autenticação, armazenamento Android, funções de notificações e migrações de permissões. O pipeline não injeta credenciais administrativas no build Flutter. Funções de envio obtêm credenciais do ambiente do servidor.
- `send-announcement` valida o usuário pelo Auth e verifica seu papel administrativo no servidor. Os dois workers com `verify_jwt=false` exigem seus respectivos segredos de cron antes de acessar dados; não são endpoints desprotegidos por esse ajuste isoladamente.
- O status de líder usa `app_metadata` atribuído por trigger do servidor, não o `user_metadata` editável. Os grants examinados não permitem ao membro alterar `profiles.role`.
- Android usa armazenamento protegido para a sessão e desabilita backup. O código de login encaminha a senha ao Supabase Auth; não foi identificado armazenamento próprio de senha nem impressão de senha nesses fluxos. A sessão web continua dependendo da segurança do navegador e da prevenção de XSS.
- HTML de capas é envolvido em iframe sem `allow-same-origin`, com CSP que bloqueia conexões e formulários. Isso reduz o risco; os testes não substituem testes de exploração em WebViews e navegadores reais.

## API publicada, sem autenticação

Executado `node tools/security-public-access-check.mjs`, somente leitura, com chave pública e `limit=0`. Nenhum registro pessoal foi baixado.

| Alvo | Resultado |
| --- | --- |
| `profiles.email` | 401 / `42501` |
| `auth.users.encrypted_password` | 406 / `PGRST106`: esquema não exposto |
| Objetivos, hábitos, inscrições push web e tokens nativos | 401 / `42501` em cada consulta |
| Solicitações e respostas de suporte | 401 / `42501` em cada consulta |
| Concessões de selos, restrições e vínculos de broadcasts | 401 / `42501` em cada consulta |

Esses resultados confirmam bloqueio dessas consultas para visitantes. Não comprovam isolamento entre duas contas autenticadas nem a aplicação de todas as migrações remotas. Consultas de zero registros verificam permissões sem testar conteúdo das linhas.

## Testes locais

- Dez testes SQL de propriedade de mídia, curtidas, privacidade de perfis e objetivos, selos administrativos, progressão e retenção: passaram.
- Dois testes SQL adicionais de suporte privado e broadcasts do líder: passaram.
- Dois testes Node de apresentação de notificações e autorização do worker: passaram.
- Oito testes Flutter de armazenamento protegido, identidade/suporte e isolamento de HTML: passaram.

Os testes SQL utilizam PGlite com fixtures locais; não equivalem a testar o banco remoto com sessões de membros.

## Limites e pendências

1. Conferir no painel Supabase o Security Advisor, confirmação de e-mail, política de senha, proteção contra senhas vazadas, limites de Auth, redirecionamentos e MFA administrativo. Não acessamos essas configurações.
2. Validar leitura e alteração cruzada entre duas contas de teste e chamadas administrativas negadas. Não foram criadas contas nem usadas sessões de membros nesta revisão.
3. Imagens em buckets públicos continuam públicas por URL. Privacidade do perfil e bloqueios não tornam esses arquivos privados.
4. Antes da distribuição pública, preparar APK release assinado. O último APK conhecido é de teste/debug; a troca de assinatura precisa considerar a atualização das instalações existentes.
5. Esta revisão não inclui auditoria completa de dependências/CVEs, análise binária do APK, teste de invasão ou inspeção dos segredos dos provedores.

Nenhuma credencial foi rotacionada, nenhuma política remota foi alterada e nenhuma notificação foi enviada. Sem commit, push ou novo APK nesta revisão.

Continuação: [proteções implementadas e etapas no painel](security-hardening-2026-11-07.md), com teste de isolamento entre membros, detector de segredos no CI, auditorias para o SQL Editor e conferência de integridade de backups.
