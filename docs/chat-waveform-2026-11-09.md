# Forma de onda dos áudios

O player mostra uma onda calculada a partir das amostras reais do arquivo. As partes ouvidas recebem a cor do tema e o progresso acompanha a posição do player, inclusive em 1,5× e 2×. Tocar ou arrastar sobre a onda permite avançar; os controles também expõem progresso para leitores de tela.

A extração começa no primeiro play, depois da autorização e do carregamento já existentes. Não há download antecipado dos áudios da conversa, nova coluna no Supabase ou upload da onda. O widget mantém somente 64 níveis de volume em memória. Antes da extração, ou se o formato não puder ser analisado, a barra fica neutra; nenhum gráfico aleatório substitui o áudio real.

No Android, MediaExtractor/MediaCodec decodificam PCM em uma tarefa fora da interface. O arquivo temporário fica no cache privado e é excluído no bloco de limpeza. O processamento tem limite de oito segundos e apenas uma extração nativa ocorre por vez. O fechamento da atividade Android interrompe o processamento em andamento. No navegador, OfflineAudioContext calcula os níveis a partir do arquivo já carregado, sem reproduzir outro som.

Permanecem os limites existentes de dois minutos, 1 MB e exclusão dos anexos após sete dias. Plataformas sem o extrator usam a barra neutra e continuam podendo reproduzir e avançar normalmente.

Os testes cobrem limite de entrada/saída, toque na posição da onda, semântica acessível e um WAV sintético com silêncio seguido de tom audível. A parte nativa exige nova compilação do aplicativo para aparecer no celular; hot reload sozinho não registra uma ponte Android nova.

Validação concluída: dez testes locais do player/chat e dois testes Chrome passaram; a compilação Android também passou. O teste Chrome precisou receber os arquivos CanvasKit originais do SDK por interceptação local na página sintética, devido a uma falha de caminhos do servidor de testes no Windows. Nenhum recurso do app ou sessão do usuário foi alterado nesse contorno.
