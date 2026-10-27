# Experiência diária — 27/10/2026

O estado anterior do projeto foi salvo e enviado à `main` no commit `a86b114`
antes de começar esta etapa.

## Início

Um botão compacto depois da saudação destaca uma ação: registrar os hábitos
pendentes, continuar uma aula iniciada, avançar no desafio ativo ou explorar
conteúdo. O resumo semanal e os detalhes da jornada permanecem no fim da tela.
A ação de continuar usa o progresso existente e abre a próxima aula pendente.

## Conquistas

Ao registrar o dia que completa um desafio, o app abre uma apresentação do troféu
com arte, título e opção de compartilhar texto pelo menu do sistema. A celebração
não aparece apenas por consultar um desafio que já estava concluído. As animações
decorativas respeitam a redução de movimento e o modo de efeitos reduzidos.

## Aulas e prática

Concluir uma aula passa a oferecer escrever uma reflexão, adicionar o hábito
associado (quando houver) ou definir um próximo passo no objetivo pessoal.
Nenhuma dessas ações extras é executada sem escolha. O objetivo existente é
preservado, e o app informa se o novo passo será público antes de salvar.
Também é possível voltar ao programa sem adicionar nada. Anotações não salvas
continuam protegidas pelo aviso ao sair.

## Comentários

O menu de cada comentário permite responder. No comentário próprio, também há
edição e exclusão. Edições efetivas recebem a indicação “editado”, sem mudar a
data original. Respostas mostram o autor do comentário original quando ele está
na página carregada; caso contrário mostram uma referência genérica.

O banco verifica autoria das edições e valida que a resposta pertence à mesma
publicação. Bloqueios são respeitados nos dois sentidos. Falhas ao salvar uma
edição mantêm o rascunho disponível ao selecionar “Editar” novamente naquela
tela. Excluir um comentário original preserva as respostas existentes.

**Ativação:** depois das migrations anteriores, execute o conteúdo completo de
`supabase/migrations/20261027000400_comment_editing_replies.sql` no SQL Editor.
Os recursos de edição e resposta dependem dessa migration. Não é preciso
publicar Edge Functions novas para esta etapa.

## Personalização

Os efeitos da moldura e da capa podem ser filtrados por Natureza, Luzes e
Celebrações. Trocar de categoria não troca a animação escolhida; “Sem animação”
permanece disponível e os bloqueios de opções exclusivas continuam em vigor.

“Ampliar prévia” abre o perfil em uma área maior, com zoom de até 2,5 vezes.
“Restaurar aparência salva” desfaz mudanças ainda não salvas de foto, capa,
estilo, efeitos e intensidade. Nome e biografia continuam no formulário.

As alterações desta etapa são código do app: o APK anterior precisa ser
recompilado para recebê-las. Testes no aparelho físico continuam pendentes,
conforme a escolha de adiar essa validação.

Validação:

```powershell
flutter analyze --no-fatal-infos
flutter test
npx --offline --yes deno test --cached-only --allow-read --allow-env supabase/tests/comment_editing_replies_test.ts
```
