# Capas GIF e HTML

No editor do perfil, use **Enviar minha capa** para selecionar PNG, JPEG, WebP, GIF animado ou HTML, até **5 MB**. A seleção usa o arquivo original, preservando os quadros do GIF. A foto do avatar continua aceitando PNG, JPEG e WebP.

As animações escolhidas no app ficam por cima da arte enviada e continuam com seus próprios controles. A área da capa mantém o mesmo tamanho e a foto de perfil fica na frente dela.

## Preparar uma arte HTML

Salve um documento HTML completo em UTF-8, com CSS e JavaScript no próprio arquivo. Incorpore imagens e fontes como URLs `data:`. Links para imagens, fontes, bibliotecas e serviços externos são bloqueados. Não há suporte a vídeos, formulários ou navegação dentro da capa.

Para enquadrar somente a arte, coloque `data-pbh-cover` no elemento principal. Também são reconhecidos `.pbh-cover`, `#cover`, `.cover`, `#banner`, `.banner` e `.stage`. Esse elemento ocupa toda a área da capa; cabeçalhos e controles externos a ele ficam fora da apresentação. Use dimensões responsivas e redimensione o canvas ao evento `resize`.

O HTML funciona no navegador, Android e iOS. No aplicativo nativo para Windows, macOS ou Linux aparece um aviso de compatibilidade; GIFs e imagens continuam disponíveis. O modo de efeitos reduzidos pausa animações CSS e os ciclos de `requestAnimationFrame`. Quando a capa sai da tela, a aba muda ou o app vai ao fundo, esses ciclos também são pausados. Temporizadores JavaScript próprios da arte não são controlados pelo app.

## Supabase

Execute **uma vez**, no SQL Editor, o conteúdo de `supabase/migrations/20261027000700_animated_profile_covers.sql`. Ele permite GIF e texto no bucket existente `profile-covers`, mantendo o limite de 5 MB e as políticas de acesso existentes.

HTML é enviado com extensão `.html` e tipo `text/plain`. O app baixa o texto e o apresenta em um iframe isolado, sem acesso à sessão do usuário nem permissão para chamadas de rede. Não altere esse tipo para `text/html` no Storage.

A dependência `file_selector` exige reiniciar o Flutter por completo; hot reload não registra plugins novos. Para testar no celular, gere e instale um APK novo. A arte específica precisa ser conferida para garantir que todos os recursos estejam incorporados e o enquadramento esteja correto.
