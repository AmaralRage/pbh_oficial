# Revisão de segurança — 5 de novembro de 2026

**Atualização posterior à revisão:** o endereço do fundador foi retirado de `lib`, `web` e `assets`. A nova identificação usa uma marca controlada pelo servidor e o suporte usa pedidos internos privados. As observações abaixo sobre o e-mail no frontend descrevem o estado encontrado na auditoria; veja [implantação da correção](private-founder-identity.md). A migração deve ser aplicada antes de publicar o app atualizado.

Não foi identificado vazamento de senha nem de chave administrativa nos arquivos examinados. Isso é uma revisão de código e de permissões públicas, não uma certificação de segurança nem um teste completo de invasão.

## Chaves, e-mails e senhas

- A chave atual em `lib/core/config/supabase_config.dart` é `sb_publishable_`, pública por definição. Ela identifica o projeto; a autorização depende de grants, RLS e verificações das funções. Não é `sb_secret_` nem `service_role`.
- As funções de envio usam chaves administrativas, VAPID e credenciais FCM por variáveis de ambiente do servidor. Não foi encontrado repasse dessas credenciais para o build Flutter. O workflow de publicação fornece ao app apenas o identificador público do Spotify.
- Foram examinados 422 arquivos de texto atuais e 949 blobs de texto do histórico Git em busca de JWT `service_role`, `sb_secret_`, cabeçalhos de chaves privadas e identificadores AWS. Nenhuma correspondência nesses padrões. Essa busca não reconhece todos os formatos de segredo e não inspeciona todos os arquivos binários.
- O app envia senhas ao Supabase Auth; não foi encontrado armazenamento de senhas em tabelas próprias nem registro delas nos logs examinados. O Supabase Auth armazena hashes de senha. Não consultamos hashes ou senhas reais.
- O endereço do fundador está fixo em `AuthService.adminEmail` e nas regras do servidor. Esse endereço pode ser conhecido por quem inspecionar o aplicativo; não equivale a acesso à conta. Removê-lo do frontend exige substituir a identificação do líder por uma informação confiável fornecida pelo servidor e coordenar a implantação. Não foi alterada a autorização do líder nesta revisão.

## Verificação real da API sem login

Executado `node tools/security-public-access-check.mjs` com a chave pública e consultas de zero registros (`limit=0`), sem sessões, criação de contas ou alterações no banco:

| Consulta | Resultado |
|---|---|
| Coluna `profiles.email` | 401 / `42501`: acesso negado |
| Esquema `auth`, coluna de hash de senha | 406 / `PGRST106`: esquema não exposto |
| Objetivos pessoais | 401 / `42501`: acesso negado |
| Inscrições de push web | 401 / `42501`: acesso negado |
| Tokens de push nativo | 401 / `42501`: acesso negado |
| Rotina de hábitos | 401 / `42501`: acesso negado |

Esses resultados comprovam o bloqueio para visitantes, não o isolamento entre quaisquer duas contas autenticadas no ambiente publicado. As migrações examinadas restringem dados privados ao proprietário e ações administrativas a verificações no servidor. E-mails administrativos aparecem em RPCs com verificação administrativa, não nos retornos públicos de identidade.

Os dez testes de banco de `build/run-review-sql.mjs` passaram, incluindo propriedade de anexos, curtidas, privacidade de perfis, concessão administrativa de selos e objetivos privados. Os testes usam banco local e não substituem validação com duas contas comuns no projeto remoto.

## Conteúdo público e sessões

- Fotos de capa, backgrounds e anexos em buckets públicos podem ser acessados por URL. Bloquear um membro ou tornar o perfil privado não torna um arquivo de bucket público confidencial. Esses espaços não devem receber documentos ou imagens privadas; conteúdo que precise de sigilo requer bucket privado e URLs assinadas.
- HTML decorativo usa iframe sem `allow-same-origin`, CSP com `connect-src 'none'` e bloqueio de formulários. Isso reduz acesso à sessão e chamadas externas pelo HTML enviado. Não foi feito teste de exploração em todos os navegadores/WebViews.
- A sessão do Auth é persistida no dispositivo. Isso mantém o login; não salva a senha digitada. O manifesto Android não define uma política explícita de backup. Recomenda-se excluir sessões dos backups e avaliar armazenamento protegido para tokens antes da distribuição pública. Não foram alteradas regras de backup sem validar restauração e compatibilidade.
- O frontend web continua sujeito a roubo de sessão caso haja XSS em código confiável ou scripts de terceiros. Não foi adicionada uma CSP global restritiva sem validar Flutter, Spotify, workers e mídias. A CSP do HTML decorativo já existe.

## Ajustes realizados

- `.gitignore`: ignora `.env`, variantes locais e arquivos `.key`, `.p12` e `.pfx`, mantendo exemplos permitidos. Isso previne novas inclusões acidentais; não apaga arquivos já versionados nem histórico.
- `web/vercel.json`: acrescenta `nosniff`, bloqueio de enquadramento externo (`X-Frame-Options: DENY`) e política de referenciador. O app não poderá ser incorporado em iframe por sites externos. É necessário publicar o build web para esses cabeçalhos entrarem em vigor. JSON validado; `git diff --check` passou.
- Script de verificação pública reutilizável, que não imprime chaves nem dados pessoais.

## Pendências antes de afirmar prontidão de produção

1. No Supabase, confirmar políticas de senha, proteção contra senhas vazadas conforme disponibilidade do plano, confirmação de e-mail, limites de Auth, CAPTCHA quando necessário e URLs de redirecionamento autorizadas. O formulário atual aceita mínimo de seis caracteres; a política efetiva do Auth não foi acessada.
2. Ativar MFA nas contas administrativas do Supabase, GitHub e hospedagem; conferir colaboradores e segredos desses serviços. Nenhuma dessas configurações foi acessada nesta revisão.
3. Testar com duas contas comuns: leitura/alteração de dados privados de outra conta e tentativas de executar RPCs administrativos. Não utilizar contas reais de membros para isso.
4. Confirmar aplicação das migrações recentes: a checagem anterior da API encontrou RPCs novos de busca, editor e preferências ainda indisponíveis. Arquivos locais não provam implantação remota.
5. Distribuir APK release assinado; o último artefato de teste conhecido é debug. Validar armazenamento/backup de sessão e realizar teste no aparelho.
6. Fazer auditoria de dependências e teste dinâmico autenticado antes de considerar esta revisão uma avaliação completa. Não foram executados ataques, testes de carga, inspeção de segredos no painel nem análise binária completa do APK.

Referências oficiais: [chaves de API](https://supabase.com/docs/guides/getting-started/api-keys), [segurança de senhas](https://supabase.com/docs/guides/auth/password-security), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).

Não houve commit, push, publicação web ou geração de APK nesta revisão.
