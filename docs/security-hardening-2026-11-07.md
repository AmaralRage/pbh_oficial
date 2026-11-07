# Proteções de segurança — 7 de novembro de 2026

## Estado real das cinco etapas

| Etapa | Implementado e validado localmente | Falta no ambiente publicado |
| --- | --- | --- |
| Isolamento de membros | Teste com duas identidades comuns, grants reais das migrações, leituras positivas e tentativas cruzadas de leitura, escrita, exclusão e RPC | Executar o teste transacional no SQL Editor; teste HTTP com duas sessões reais de teste continua separado |
| Verificações automáticas | Detector de credenciais e bateria de permissões no CI; nova etapa bloqueia o build seguinte se falhar | Commit/push para o workflow entrar em vigor; regra de proteção da branch depende do GitHub |
| Configuração Supabase | Auditoria SQL somente leitura preparada e testada | Executar no painel e conferir Security Advisor/Auth |
| Acessos administrativos | Procedimento e critérios de conclusão abaixo | O titular deve cadastrar MFA, guardar recuperação e revisar colaboradores |
| Arquivos e recuperação | Auditoria de buckets e ferramenta de integridade com testes de corrupção/exclusão | Exportar backup real, copiar Storage e restaurar em ambiente isolado |

Não há conector Supabase/GitHub/Vercel autenticado disponível nesta sessão. Nenhuma chave administrativa deve ser colocada no frontend, no chat ou nos arquivos versionados para contornar essa limitação. Não foram acessadas contas reais de membros nem alteradas configurações remotas.

## 1. Confirmar o isolamento no banco publicado

Execute **o arquivo inteiro** [member_isolation_rollback.sql](../supabase/audits/member_isolation_rollback.sql) no SQL Editor, como proprietário, preferencialmente primeiro em staging. O teste usa duas identidades aleatórias `@example.invalid`, faz verificações e termina com `ROLLBACK`. Não usa IDs de membros existentes nem envia push. Se houver erro/interrupção, execute `ROLLBACK` antes de continuar.

Resultado esperado: `PASS: two-member SQL isolation; all fixtures rolled back`. A ausência desse resultado não é aprovação. Políticas ausentes, migrações não aplicadas e permissões inesperadas devem interromper o teste. Os arquivos em `supabase/audits` não são migrações e não devem ser aplicados automaticamente como mudanças permanentes.

Esse teste valida SQL/RLS/RPCs com os papéis do banco; não faz login pela API do Auth. Para completar a validação ponta a ponta, use duas contas descartáveis de staging pelo app: criar dados próprios, tentar operações sobre IDs conhecidos apenas dessas contas e confirmar que o acesso é negado. Não forneça sessões ou senhas pelo chat.

## 2. Executar e manter a proteção automática

Requer Node 24. Na raiz do projeto:

```powershell
node tools/security-secret-scan.mjs --history
node --test tools/test-security-secret-scan.mjs tools/test-backup-integrity.mjs tools/test-announcement-worker.mjs tools/test-community-notification-presentation.mjs
npm install --prefix build/security-deps --no-save --ignore-scripts @electric-sql/pglite@0.3.16
node tools/run-security-tests.mjs
```

O detector mostra somente tipo/localização, não os valores encontrados. Inspeciona texto versionado e arquivos novos não ignorados, histórico Git alcançável e, se existente, o frontend compilado. Bloqueia padrões conhecidos de chave administrativa, JWT `service_role`, chaves privadas, IDs AWS e arquivos de credenciais. Não reconhece todos os segredos possíveis e não analisa binários. A chave `sb_publishable_` é permitida.

O CI agora executa segurança antes do Flutter e confere novamente o build web. No GitHub, configurar a ruleset da `main` para exigir os checks `security` e `checks` e ativar secret scanning/push protection quando disponíveis. A alteração do workflow local não ativa sozinha essas configurações do repositório.

O script `security-public-access-check.mjs` continua somente leitura (`limit=0`) e agora termina com erro se uma consulta não receber a negativa esperada ou se a conexão falhar.

## 3. Conferir o painel Supabase

Execute [security_configuration.sql](../supabase/audits/security_configuration.sql). É somente leitura, não retorna e-mails, tokens ou corpos de mensagens. Conferir tabelas presentes, RLS ativo, flags de acesso público falsas nas tabelas privadas, e-mail sem leitura pelos clientes, alteração de papel administrativo proibida e helpers internos sem execução pelo cliente. Funções sem `search_path` explícito precisam de revisão; não revogar indiscriminadamente RPCs públicos válidos.

No painel, registrar em evidência privada a data e o resultado de:

- Security Advisor: investigar cada alerta relevante; não desativar RLS para silenciá-lo.
- Auth: confirmação de e-mail, mínimo recomendado de 12 caracteres para novas senhas, proteção contra senhas vazadas quando disponível, limites de tentativas/envios e proteção contra abuso de cadastro/recuperação. A validação efetiva deve estar no servidor. O formulário local ainda aceita 6 caracteres e deve ser alinhado à política escolhida depois da configuração do Auth; não mudar a validação de login de senhas existentes.
- Site URL e redirecionamentos: somente o domínio publicado e os retornos mobile realmente necessários; desenvolvimento separado de produção, sem wildcards amplos de terceiros.
- Funções/secrets: credenciais administrativas apenas no ambiente das funções; confirmar segredos de cron. Workers com `verify_jwt=false` dependem da verificação própria do segredo, não de acesso livre.

Referências: [segurança de senhas](https://supabase.com/docs/guides/auth/password-security), [autenticação por senha e redirecionamentos](https://supabase.com/docs/guides/auth/passwords).

## 4. Proteger os administradores

O proprietário deve ativar MFA no Supabase, GitHub e hospedagem, concluir a confirmação e guardar os códigos de recuperação em local privado separado do dispositivo. Conferir uma segunda forma de recuperação antes de encerrar a sessão existente. Revisar colaboradores e manter apenas os acessos necessários; remover acessos antigos, revisar tokens e sessões do painel.

Isso protege as contas dos provedores. Não foi adicionado um bloqueio novo de MFA ao login dos membros do app. Não compartilhar QR codes, códigos TOTP ou códigos de recuperação nesta conversa.

Referência: [MFA da conta Supabase](https://supabase.com/docs/guides/platform/multi-factor-authentication).

## 5. Arquivos, backup e teste de recuperação

O código configura `profile-avatars`, `profile-covers` e `profile-backgrounds` como arte pública; `community-photos` é privado. A auditoria SQL confirma a configuração efetivamente publicada e aponta buckets públicos inesperados. Perfil privado não torna arte de bucket público confidencial. Tornar esses buckets privados exige adaptar URLs e leitores do app; não foi feito um bloqueio que quebraria imagens existentes.

Definir a frequência conforme a perda de dados aceitável; ponto de partida: cópia diária, retenção de 7 diárias e 4 semanais, armazenamento externo criptografado e acesso restrito. Isso é uma política proposta, não um agendamento já ativado.

Procedimento de recuperação a concluir pelo proprietário:

1. Identificar o plano, a disponibilidade de backups e o último ponto restaurável. Exportar um backup conforme o procedimento oficial; se usar CLI, guardar roles, schema e dados e verificar cobertura de Auth, triggers e políticas customizadas em `auth`/`storage`. Um dump padrão não deve ser presumido completo. Manter também a revisão Git, configuração e inventário privado dos secrets necessários.
2. Copiar os bytes de **todos** os buckets para uma cópia externa, incluindo privados. O backup do banco não inclui os arquivos do Storage. Comparar inventário, quantidades e arquivos esperados, preferencialmente em janela sem escritas para evitar uma cópia inconsistente.
3. Guardar exportações apenas fora do repositório ou em `backups/`/`security-private/`, agora ignorados. Criptografar a cópia externa. Dumps podem conter dados pessoais e material de autenticação; não anexar ao GitHub ou ao chat.
4. Para conferir cópias lógicas, organizar `roles.sql`, `schema.sql`, `data.sql` e `storage/<bucket>/...` em uma pasta privada. Executar os comandos abaixo antes e depois da cópia. Manifesto não cifra nem autentica contra adulteração de quem consegue substituir também o manifesto.

```powershell
node tools/backup-integrity.mjs create backups/snapshot-local
node tools/backup-integrity.mjs verify backups/snapshot-local
```

5. Restaurar em um projeto de teste isolado seguindo a documentação, **sem** credenciais de push/SMTP de produção ou cron/webhooks externos ativos. Repor personalizações de `auth`/`storage`, políticas e arquivos do Storage pela API apropriada. Não executar restauração sobre produção para testar.
6. Executar as duas auditorias SQL no destino; conferir contagens, leitura das fotos e entrada de duas contas de teste. Confirmar que credenciais push restauradas não disparam mensagens reais. Registrar tempo, resultado e falhas em evidência privada. Só então marcar a recuperação como validada.

A ferramenta verifica bytes e detecta corrupção, arquivos excluídos ou inesperados. Não prova que o backup era completo na origem nem que pode ser restaurado; o resultado distingue explicitamente `content_integrity_verified` de `restoration_tested`.

Referências: [backups e limites do Storage](https://supabase.com/docs/guides/platform/backups), [procedimento oficial de backup/restauração](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).

## Validação desta entrega

Teste de isolamento e auditorias SQL executados em PGlite, com rollback verificado. Detector de segredos, testes dos workers/apresentação e teste de integridade executados localmente. Nenhum resultado local é apresentado como ativação de MFA, configuração do painel ou restauração de backup real. Sem commit, push ou atualização de APK nesta etapa.
