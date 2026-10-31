# Backgrounds do perfil

Execute o arquivo completo `supabase/migrations/20261030000400_profile_backgrounds.sql`
no SQL Editor após as migrações anteriores do perfil. Não reaplique as antigas.
A migração cria o bucket e mantém os filtros de privacidade e as recompensas
existentes na RPC do perfil público.

No app: **Perfil → Personalizar perfil → Fundo**. Há Padrão, Essência PBH,
Biblioteca e Astral, com fundos estáticos desenhados no aplicativo. Essas opções
iniciais são composições simples; não são as imagens da simulação visual.
Novas artes poderão entrar no catálogo posteriormente.

**Enviar meu background** aceita PNG, JPEG ou WebP de até 5 MB. O seletor solicita
redução para até 1600 × 2560 px quando suportado pela plataforma. Fotos verticais
preenchem melhor a área; a imagem usa recorte para preencher a tela, ancorada
no topo. Não há envio de HTML, GIF ou vídeo para backgrounds nesta versão.

O fundo fica parado atrás do conteúdo rolável. Capa, moldura, animações e cores
dos cards continuam independentes. A aba de personalização e a prévia ampliada
mostram as alterações antes de salvar. O controle Escurecimento vai de 0 a 85%.
**Restaurar fundo padrão** desfaz a escolha e remove o arquivo anterior ao salvar.
**Restaurar aparência salva** descarta apenas as alterações ainda não salvas.
Selecionar outro fundo pronto mantém a imagem salva disponível em Minha imagem.

As escolhas ficam em `profile_style` na conta; não são preferências do aparelho.
O perfil próprio acompanha a sessão, e visitantes recebem os dados pela mesma
RPC pública do perfil. Visitantes sem conta não recebem backgrounds de outra
sessão. O servidor verifica o caminho do arquivo e só retorna imagens do dono
do perfil. Nenhum email ou metadado privado adicional é retornado.

Como nas capas, o bucket contém artes com URL pública: não envie informações
sigilosas. O perfil privado e os bloqueios impedem abrir a página, mas alguém
que já tenha a URL da imagem pode continuar a acessá-la. Armazenamento e tráfego
usam as cotas do Supabase existente, sem nova API ou serviço de geração.

Validação: `test/profile_background_test.dart`, testes de personalização do perfil
e `supabase/tests/profile_backgrounds_test.ts` (PostgreSQL embarcado). A validação
em aparelho físico continua pendente.
