# APK 1.0.1+55 — 7 de novembro de 2026

Arquivo: `build/releases/PBH-Oficial-v1.0.1-build55-teste.apk`.

SHA-256: `1583CFF145D836624813E0DCC2827F2E186D06C49449276180D6EA5E607738DB`.

Inclui o chat com áudios de até dois minutos, notificações com foto/nome/prévia e duração dos áudios, indicador de digitação, velocidades 1×/1,5×/2×, resposta ao arrastar, busca na conversa e silenciamento individual. Também inclui a correção dos avatares, o escurecimento do papel de parede e os ajustes recentes do gravador. Mensagens e anexos continuam expirando após sete dias.

Compilado em Debug para atualizar a instalação de testes existente. O verificador confirmou pacote `com.amaralstudios.pbh_oficial`, mesmo certificado e versionCode 54 → 55. Nenhuma chave de assinatura foi alterada. O APK fica em `build/releases`, fora do Git, como nas versões anteriores.

Passaram 281 testes Flutter, 16 cenários SQL locais e 17 testes Node. O analisador não apontou erros nem warnings; permanecem lints informativos. O detector de segredos não encontrou ocorrências nos arquivos examinados. A compilação `assembleDebug` e a verificação de compatibilidade passaram.

As migrações de áudio, prévias de notificação e experiência do chat estão ativas no Supabase. As funções `validate-chat-audio` e `process-private-chat` estão publicadas. RLS, Realtime da digitação e limpeza automática foram conferidos no remoto, sem consultar conteúdo real das conversas nem enviar notificações a membros.

A conferência física com dois celulares fica para a instalação deste APK. Siga [o roteiro de teste](chat-experience-2026-11-07.md). O Android determina o formato final da notificação; sua entrega em segundo plano e o uso real do microfone devem ser conferidos no aparelho.

O script de build agora considera o código de saída do Flutter, evitando que avisos do Java no PowerShell 5 interrompam uma compilação bem-sucedida. A assinatura e a comparação de versões continuam obrigatórias quando o APK anterior é informado.
