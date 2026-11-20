# PBH Oficial 1.0 Beta 3 — build 59

Data: 20 de novembro de 2026.

Versão técnica: `1.0.0-beta.3+59`.

Corrige o alinhamento das mensagens de texto: o conteúdo permanece alinhado ao
início do balão, com espaço reservado para horário e confirmação no canto inferior
direito. A reserva acompanha o tamanho de texto do sistema, evitando sobreposição
em mensagens curtas, longas ou com múltiplas linhas.

Validação: 17 testes aprovados de geometria, experiência da conversa e envio.
Inclui fontes ampliadas e mensagens com quebras de linha.

Não requer alteração no Supabase. Mantém a assinatura de teste das versões
anteriores. O APK e o checksum ficam em `build/releases`, fora do Git.
Ainda requer conferência visual no celular.

APK: `build/releases/PBH-Oficial-v1.0.0-beta.3-build59-teste.apk`.

Assinatura e compatibilidade confirmadas: mesmo certificado e versionCode 58 → 59.

SHA-256: `314FDF49E58A424CE15A6320D5EAE519840BAA188AE131F1841CEADEB370EE89`.

Análise dos arquivos corrigidos sem apontamentos. Verificação de segredos em
719 arquivos sem ocorrências.
