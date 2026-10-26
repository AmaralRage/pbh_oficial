import 'program_media_catalog.dart';
import 'program_lesson.dart';

// IDs publicados são estáveis para preservar o progresso entre versões.
const programCurricula = <String, List<ProgramModule>>{
  'niilismo_sentido': [
    ProgramModule(
      id: 'compreender_niilismo',
      title: 'Entender o niilismo e seus riscos',
      lessons: [
        ProgramLesson(
          id: 'niilismo_significado',
          title: 'O que significa dizer que nada importa?',
          media: nihilismMedia,
          body:
              'Niilismo é um nome usado para posições e problemas filosóficos diferentes. Neste programa, o foco é o niilismo existencial: o questionamento de um sentido ou propósito objetivo dado de antemão à vida. Isso não resume todas as formas de niilismo.\n\nNietzsche investigou a crise dos valores tradicionais e a possibilidade de criar valores. Sua reflexão vai além de repetir que nada vale a pena. Questionar uma certeza pode abrir uma investigação; concluir que nenhuma escolha merece cuidado é um passo adicional que precisa ser examinado.',
          practice:
              'Assista ao vídeo e anote uma ideia que você entendeu e uma pergunta que ainda tem. Diferencie uma dúvida sobre sentido de uma conclusão sobre como agir.',
        ),
        ProgramLesson(
          id: 'niilismo_riscos',
          title: 'Quando o vazio vira uma justificativa para desistir',
          media: nihilismMedia,
          body:
              'O risco abordado aqui aparece quando a frase “nada importa” passa a justificar abandonar compromissos, desprezar vínculos ou tratar qualquer esforço como inútil. Uma dúvida filosófica pode se tornar uma conclusão rígida que encerra a reflexão antes de examinar alternativas.\n\nImagine deixar de conversar com alguém importante porque nenhuma relação durará para sempre. A duração limitada não demonstra que essa conversa é sem valor. Em vez de assumir que tudo é indiferente, pergunte o que sua escolha muda para você e para as pessoas envolvidas. Essa é uma aplicação prática para reflexão, não uma consequência inevitável de estudar niilismo.',
          practice:
              'Escolha uma situação em que pensou “tanto faz”. Descreva duas ações possíveis e as consequências concretas de cada uma.',
        ),
      ],
    ),
    ProgramModule(
      id: 'reconstruir_sentido',
      title: 'Valores, vínculos e responsabilidade',
      lessons: [
        ProgramLesson(
          id: 'niilismo_responsabilidade',
          title: 'Questionar valores não elimina consequências',
          media: nihilismMedia,
          body:
              'Não encontrar um propósito universal não prova, por si só, que todas as ações sejam equivalentes. Pessoas continuam sendo afetadas por promessas, escolhas e omissões. É possível discutir de onde vêm os valores e, ao mesmo tempo, considerar cuidado, reciprocidade e responsabilidade nas decisões.\n\nUma forma de examinar uma escolha é perguntar: quem será afetado, que dano posso evitar e que razões consigo explicar aos envolvidos? Você não precisa resolver todas as questões da filosofia para reconhecer um compromisso concreto. Essa proposta de reflexão não pretende ser a única resposta possível ao niilismo.',
          practice:
              'Relembre um compromisso com outra pessoa. Escreva por que cumpri-lo ou renegociá-lo importa, mesmo sem uma certeza sobre o sentido da vida.',
        ),
        ProgramLesson(
          id: 'niilismo_compromissos',
          title: 'Experimente um sentido em ações pequenas',
          media: nihilismMedia,
          body:
              'Uma resposta possível à perda de referências é investigar quais atividades e relações você considera dignas de cuidado. Aprender algo, criar, colaborar ou estar presente em uma conversa são possibilidades para explorar; nenhuma precisa valer como resposta para todas as pessoas.\n\nEscolha um compromisso pequeno, explique sua razão e observe a experiência. Depois revise: o que teve valor, o que não fez sentido e o que deseja mudar? Construir uma orientação não exige fingir certeza nem transformar produtividade em medida de valor pessoal. A proposta é manter a reflexão aberta enquanto participa da vida cotidiana.',
          practice:
              'Reserve um momento para ler sobre uma pergunta que importa para você. Registre um aprendizado e uma ação possível para os próximos dias.',
          habitKey: 'read',
        ),
      ],
    ),
  ],
  'fundamentos_homem_valor': [
    ProgramModule(
      id: 'base',
      title: 'Uma base com propósito',
      lessons: [
        ProgramLesson(
          id: 'valores',
          media: habitsMedia,
          title: 'Transforme valores em escolhas',
          body:
              'Um valor fica concreto quando orienta uma decisão. Dizer que valoriza a honestidade ganha sentido ao admitir um erro; valorizar a presença aparece ao guardar o celular durante uma conversa.\n\nEscolha um valor importante para você e descreva uma atitude observável que o represente. Evite metas que dependam da aprovação dos outros. Uma ação pequena, repetida, ajuda a aproximar suas escolhas do que você considera importante.',
          practice:
              'Escreva um valor e uma ação de hoje que o coloque em prática.',
        ),
        ProgramLesson(
          id: 'rotina_minima',
          media: habitsMedia,
          title: 'Comece por uma rotina possível',
          body:
              'Uma rotina precisa caber no seu dia real. Planejar muitas mudanças de uma vez pode dificultar a continuidade. Comece escolhendo um horário e uma atividade que você consegue repetir.\n\nUma leitura curta depois do café, por exemplo, tem um momento de início claro. Em dias difíceis, reduza o tamanho da atividade e retome quando puder. Um registro serve para observar seu caminho, não para medir seu valor pessoal.',
          practice:
              'Escolha um horário de leitura e separe o material antes de começar.',
          habitKey: 'read',
        ),
      ],
    ),
    ProgramModule(
      id: 'consistencia',
      title: 'Consistência e responsabilidade',
      lessons: [
        ProgramLesson(
          id: 'ambiente',
          media: habitsMedia,
          title: 'Prepare o ambiente',
          body:
              'O ambiente pode facilitar ou atrapalhar uma escolha. Um livro acessível lembra a leitura; notificações frequentes interrompem uma atividade. Observe o que acontece antes de um hábito que deseja manter.\n\nEm vez de depender apenas da vontade, retire um obstáculo: deixe o material pronto, reserve um espaço ou silencie interrupções durante um período combinado. Teste uma mudança por vez para descobrir o que ajuda você.',
          practice:
              'Prepare um espaço de estudo e faça uma leitura curta nele.',
          habitKey: 'read',
        ),
        ProgramLesson(
          id: 'revisao',
          media: habitsMedia,
          title: 'Revise sem se punir',
          body:
              'Uma revisão útil descreve fatos. “Li em dois dias” informa mais do que “não tenho disciplina”. Olhe para o que aconteceu, quais condições ajudaram e quais dificultaram.\n\nDepois escolha um ajuste possível para a próxima semana. Você pode mudar o horário, reduzir uma meta ou pedir apoio. O objetivo é aprender com a experiência e continuar com um plano que respeite seus limites e suas responsabilidades.',
          practice:
              'Anote uma coisa que funcionou e um ajuste para a próxima semana.',
        ),
      ],
    ),
  ],
  'lideranca_silenciosa': [
    ProgramModule(
      id: 'escuta',
      title: 'Presença e escuta',
      lessons: [
        ProgramLesson(
          id: 'ouvir',
          media: leadershipMedia,
          title: 'Escute antes de responder',
          body:
              'Escutar envolve compreender o que a outra pessoa está tentando comunicar. Durante uma conversa, perceba se você está acompanhando a fala ou apenas preparando uma resposta.\n\nEspere a pessoa concluir e confirme sua compreensão: “Entendi que sua dificuldade é esta; faz sentido?”. A confirmação evita respostas baseadas em suposições. Escutar não exige concordar com tudo, mas cria condições para uma conversa mais clara e respeitosa.',
          practice:
              'Em uma conversa, confirme o que entendeu antes de dar sua opinião.',
        ),
        ProgramLesson(
          id: 'comunicar',
          media: leadershipMedia,
          title: 'Faça pedidos claros',
          body:
              'Um pedido claro descreve uma ação, um contexto e um prazo possível. “Preciso da sua ajuda” pode abrir a conversa, mas deixa detalhes importantes em aberto.\n\nExplique o que precisa, por que isso importa e pergunte se a pessoa consegue assumir o combinado. Dê espaço para negociar. Quando há limites ou desacordo, nomeie o problema sem atacar a pessoa. Clareza e respeito ajudam a evitar expectativas que ninguém combinou.',
          practice:
              'Reescreva um pedido usando ação, contexto e prazo negociável.',
        ),
      ],
    ),
    ProgramModule(
      id: 'exemplo',
      title: 'Liderança em prática',
      lessons: [
        ProgramLesson(
          id: 'compromissos',
          media: leadershipMedia,
          title: 'Cuide dos compromissos',
          body:
              'Confiança se constrói também nos pequenos combinados. Antes de assumir uma tarefa, confira se tem tempo e condições para realizá-la. Dizer sim a tudo pode gerar promessas difíceis de cumprir.\n\nSe perceber que vai atrasar, avise com antecedência, explique a situação e proponha um novo acordo. Assumir responsabilidade inclui reconhecer limites. O exemplo está na forma como você trata os compromissos e as pessoas envolvidas.',
          practice:
              'Revise um compromisso pendente e confirme ou renegocie o prazo.',
        ),
        ProgramLesson(
          id: 'feedback',
          media: leadershipMedia,
          title: 'Converse sobre melhorias',
          body:
              'Uma conversa de melhoria funciona melhor com exemplos concretos. Descreva o que observou e seu impacto, evitando rótulos como “você sempre faz isso”. Depois ouça a perspectiva da outra pessoa.\n\nCombinem um próximo passo pequeno e uma ocasião para revisar. Ao receber uma observação, peça exemplos se precisar e reserve tempo para pensar. Respeito não elimina o desacordo; ajuda a lidar com ele sem humilhação ou imposição.',
          practice:
              'Prepare uma observação concreta e uma pergunta aberta para uma conversa.',
        ),
      ],
    ),
  ],
  'estoicismo_pratico': [
    ProgramModule(
      id: 'controle',
      title: 'Foco no que você controla',
      lessons: [
        ProgramLesson(
          id: 'escolhas',
          media: stoicismMedia,
          title: 'Separe fatos e escolhas',
          body:
              'Você não decide o trânsito, o clima ou a reação de outra pessoa. Pode escolher como se preparar, o que comunicar e qual atitude tomar diante dessas condições. Essa distinção ajuda a direcionar seu esforço.\n\nPense em uma situação recente. Separe o fato, a interpretação que fez e a ação que está ao seu alcance. Aceitar que algo aconteceu não significa aprová-lo: você ainda pode procurar ajuda, estabelecer limites e agir para mudar o que for possível.',
          practice:
              'Divida uma preocupação em duas listas: o que posso fazer e o que não depende de mim.',
        ),
        ProgramLesson(
          id: 'pausa',
          media: stoicismMedia,
          title: 'Crie uma pausa antes da resposta',
          body:
              'Entre perceber um acontecimento e responder, às vezes é possível criar uma pausa. Ao notar pressa para reagir, observe a situação e dê nome ao que está sentindo.\n\nPergunte: “O que sei de fato? Qual resposta combina com meus valores?”. Se for seguro e possível, adie uma mensagem ou uma decisão até conseguir pensar com mais clareza. Uma pausa não resolve todos os problemas; ela abre espaço para uma escolha mais deliberada.',
          practice:
              'Reserve alguns minutos em silêncio para refletir sobre uma resposta que quer dar.',
          habitKey: 'meditate',
        ),
      ],
    ),
    ProgramModule(
      id: 'cotidiano',
      title: 'Aplicação no cotidiano',
      lessons: [
        ProgramLesson(
          id: 'imprevistos',
          media: stoicismMedia,
          title: 'Prepare uma alternativa',
          body:
              'Planos encontram imprevistos. Uma alternativa simples evita tratar qualquer mudança como o fim do plano. Se você costuma ler à noite, pode separar um horário menor em outro momento quando surgir um compromisso.\n\nDefina uma condição e uma resposta: “Se meu horário mudar, vou escolher outro momento possível”. A alternativa precisa ser flexível e respeitar suas necessidades. Adaptar a ação pode ser mais útil do que insistir em um plano que deixou de caber no dia.',
          practice:
              'Escreva uma alternativa para um hábito que costuma ser interrompido.',
          habitKey: 'read',
        ),
        ProgramLesson(
          id: 'reflexao',
          media: stoicismMedia,
          title: 'Encerre o dia com uma revisão',
          body:
              'Uma reflexão breve pode ajudar a perceber padrões. Relembre uma escolha de hoje e observe o que a influenciou. Procure uma atitude que gostaria de repetir e outra que gostaria de ajustar.\n\nEvite transformar a revisão em julgamento sobre quem você é. Registre algo específico e encerre com um próximo passo possível. A proposta é aprender com o dia, mantendo abertura para mudar de ideia e reconhecer situações em que você precisa de apoio.',
          practice:
              'Escreva: o que aprendi hoje e qual escolha quero experimentar amanhã.',
          habitKey: 'meditate',
        ),
      ],
    ),
  ],
  'corpo_combate': [
    ProgramModule(
      id: 'preparacao',
      title: 'Prepare sua consistência',
      lessons: [
        ProgramLesson(
          id: 'objetivo',
          media: movementMedia,
          title: 'Defina um objetivo possível',
          body:
              'Antes de escolher uma rotina de movimento, pense no que deseja e nas condições de que dispõe. Tempo, acesso a espaços e preferências influenciam a continuidade. Um objetivo precisa respeitar suas condições individuais.\n\nEste programa trabalha organização e reflexão, sem prescrever exercícios ou substituir orientação profissional. Você pode começar planejando quando e onde pretende se movimentar e buscar uma orientação adequada para escolher atividades compatíveis com você.',
          practice:
              'Anote seu objetivo e dois horários possíveis para uma atividade adequada a você.',
        ),
        ProgramLesson(
          id: 'preparar',
          media: movementMedia,
          title: 'Reduza os obstáculos para começar',
          body:
              'Preparar o necessário com antecedência torna o início mais simples. Separe roupas, confira o local e considere o tempo de deslocamento. Veja se o horário escolhido compete com algum compromisso importante.\n\nSe surgir um impedimento, ajuste o plano sem tentar compensar com esforço excessivo. A proposta é construir uma organização sustentável. Ao escolher e realizar uma atividade, respeite seus limites e a orientação dos profissionais que acompanham você.',
          practice:
              'Prepare o material para sua próxima atividade já planejada.',
          habitKey: 'train',
        ),
      ],
    ),
    ProgramModule(
      id: 'continuidade',
      title: 'Mantenha um plano sustentável',
      lessons: [
        ProgramLesson(
          id: 'registro',
          media: movementMedia,
          title: 'Observe sua experiência',
          body:
              'Um registro simples ajuda a entender como a rotina se encaixa na sua vida. Anote a atividade realizada, o tempo reservado e como foi organizar o dia para participar.\n\nEvite usar comparações com outras pessoas como medida de sucesso. Observe suas próprias condições e leve dúvidas sobre exercícios, desconfortos ou mudanças de intensidade a um profissional qualificado. Aqui o foco é acompanhar sua organização, sem definir cargas, técnicas ou metas físicas individuais.',
          practice:
              'Depois de uma atividade, registre o que facilitou sua participação e o que precisa ajustar.',
        ),
        ProgramLesson(
          id: 'equilibrio',
          media: movementMedia,
          title: 'Inclua descanso no planejamento',
          body:
              'Uma agenda sustentável reserva espaço para diferentes necessidades: trabalho, relações, movimento e descanso. Preencher todo horário livre com novas metas pode tornar o plano difícil de manter.\n\nRevise sua semana e observe se há compromissos em excesso. Prepare uma transição tranquila para encerrar o dia, conforme suas possibilidades. Necessidades individuais variam; esta reflexão é uma proposta de organização, e não uma orientação clínica sobre sono ou recuperação.',
          practice:
              'Escolha um horário viável para começar a encerrar as atividades do dia.',
          habitKey: 'sleep_early',
        ),
      ],
    ),
  ],
};
