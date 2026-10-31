# Revisão de experiência — 30/10/2026

## Alterações em sequência

1. **Revisão do APK:** não havia Android conectado ao ADB. A validação física
   continua pendente; os testes automáticos não são tratados como teste no celular.
   O build 48 de teste reúne as melhorias abaixo para essa revisão.
2. **Personalização:** opções agrupadas em disponíveis, recompensas de jornadas
   e exclusivas. O filtro de recompensas chama-se Jornadas, pois inclui platina e
   rubi. A Coroa Suprema continua completamente ausente para quem não a recebeu.
   Platina, rubi e até três destaques preservam o layout responsivo existente.
3. **Conteúdo:** resumo da trilha, próxima aula e estimativa restante de leitura
   e prática; vídeos/podcasts têm duração adicional, não estimada pelo app.
   Módulos recebem números de etapa, a próxima aula fica destacada e cada etapa
   apresenta a prática da sua aula final. Qualquer aula continua acessível.
   A atividade final não marca conclusões automaticamente.
4. **Desafios:** ativos primeiro na lista geral; cartões mostram progresso e
   próximo marco de registros (25%, 50%, 75% e conclusão, arredondados para cima).
   Nos detalhes, calendário mensal somente de consulta, com registros reais da
   conta e retentativa em falhas. Não inventa datas para privilégios do fundador.
   Uma falha de leitura não é apresentada como mês sem registros.
5. **Apresentação de novos membros:** duas etapas opcionais no primeiro acesso
   autenticado após criar uma conta e confirmar o e-mail. Visitantes e contas
   antigas seguem direto. A escolha de rotina, aprendizado ou desafio abre a
   área indicada. Concluir ou pular atualiza a conta e uma cópia local por usuário;
   a marca antiga por aparelho não é usada. Não cria objetivo público, inscrição
   ou progresso automaticamente. Se a sincronização falhar, a cópia local evita
   repetições no aparelho; outro aparelho poderá mostrá-la até a conta sincronizar.
6. **Documentação:** guias alinhados ao Rubi do Conhecimento, à sincronização de
   anotações, às recompensas atuais e à versão 1.0.1+49. Resultados antigos de
   validação permanecem identificados como históricos.

Nenhuma migração SQL nova é necessária. As regras de RLS e o histórico existente
continuam sendo usados; nenhuma alteração é aplicada ao Supabase por este trabalho.

## Revisão física ainda necessária

Instalar `build/releases/PBH-Oficial-v1.0.1-build49-teste.apk`. Conferir:

- Primeira apresentação, escolha dos três destinos, pular e reabrir o app.
- Visitante sem moldura; login, logout e troca entre duas contas.
- Molduras com intensidades mínima/máxima e modo de efeitos reduzidos.
- Platina e rubi: abrir/fechar dez vezes, sincronismo do som e som desativado.
- Perfil com cinco miniaturas, nome comprido, fonte ampliada e tela pequena.
- Aula, prática, anotação sem conexão e sincronização ao voltar.
- Calendário: registrar hoje, desmarcar hoje e navegar entre meses reais.
- Notificações: permissão inicial/recusa, segundo plano e configuração de som.

Para medir fluidez/memória, usar `flutter run --profile -d ID_DO_APARELHO` e o
DevTools. O APK de teste é debug; sua fluidez não é medida de uma versão release.
Não declarar entrega de notificações ou desempenho físico sem essa revisão.
