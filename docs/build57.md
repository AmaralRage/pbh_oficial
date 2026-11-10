# PBH Oficial 1.0 Beta — Beta 1, build 57

Data: 9 de novembro de 2026.

Versão técnica: `1.0.0-beta.1+57`. A tela de configurações mostra **Versão 1.0 Beta · build 57**. O nome público da versão é 1.0 Beta; o contador Android continua crescente para permitir atualização das instalações existentes.

APK: `build/releases/PBH-Oficial-v1.0.0-beta.1-build57-teste.apk`.

SHA-256: `80E3FC4AC14CD081C7C6C5C2FB0EAA71E672B5925BFAA05B99C2971295263D17`.

## Incluído

- Novo visual das conversas e da lista: avatares, agrupamento de mensagens, horários fora das bolhas, datas, prévias de áudio/foto, não lidas e silenciamento.
- Papel de parede contínuo até o campo de mensagem, preservando o escurecimento escolhido.
- Forma de onda extraída do áudio real, progresso interativo e velocidades de reprodução.
- Prévia de foto em tela cheia com legenda e confirmação antes de enviar.
- Visualizador com zoom, compartilhamento e salvamento da foto. As ações verificam novamente o acesso e não exportam URLs privadas.
- Reenvio de tentativas sem confirmação usando o mesmo identificador e rascunho protegido.
- Retorno às mensagens recentes com contador, faixa das mensagens inicialmente não lidas e ajustes de acessibilidade.
- Tema **Grafite · Clássico**, com as superfícies do tema do fundador e detalhes cinza.
- Menus e controles de fotos redesenhados nas cores do tema.

## Atualização e backend

Compilado em Debug para manter o certificado dos APKs de teste instalados. O verificador confirmou pacote `com.amaralstudios.pbh_oficial`, mesmo certificado e versionCode 56 → 57. Nenhuma chave de assinatura foi alterada. O APK e seu checksum ficam fora do Git, em `build/releases`, como nas versões anteriores.

As migrations `20261109000100_chat_inbox_details.sql` e `20261109000200_graphite_profile_theme.sql` já foram aplicadas no Supabase. Nenhuma execução manual adicional é necessária para esta versão.

O SDK Android e o microfone real, o seletor de compartilhamento e a entrega de notificações devem ser conferidos no celular depois da instalação. Os testes automatizados usam contas e arquivos fictícios; não enviam mensagens a membros. O roteiro com duas contas está em [chat-experience-2026-11-07.md](chat-experience-2026-11-07.md).

## Validação

As verificações de banco, serviços e credenciais passaram: 16 cenários SQL, 18 testes Node e nenhuma ocorrência no detector de segredos, incluindo histórico Git. A análise Flutter não apontou erros nem warnings; permanecem lints informativos.

A execução completa final passou com **298 testes Flutter**. A versão gravada no manifesto Android foi conferida como `1.0.0-beta.1`, com `versionCode=57`.

O teste de expiração da foto usa avanço de tempo virtual, evitando que a inicialização lenta da máquina faça a foto expirar antes da primeira renderização. A implementação de expiração do aplicativo não foi alterada por esse ajuste no teste.
