import 'package:flutter/material.dart';

enum WelcomeFocus { explore, habits, learning, challenges }

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onFinish});
  final ValueChanged<WelcomeFocus> onFinish;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  var _step = 0;
  WelcomeFocus _focus = WelcomeFocus.habits;
  bool _finished = false;
  void _finish(WelcomeFocus focus) {
    if (_finished) return;
    setState(() => _finished = true);
    widget.onFinish(focus);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Seu começo no PBH'),
      actions: [
        TextButton(
          onPressed: _finished ? null : () => _finish(WelcomeFocus.explore),
          child: const Text('Pular'),
        ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        key: ValueKey(_step),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Passo ${_step + 1} de 2',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 16),
            Text(
              _step == 0
                  ? 'Pequenos passos, todos os dias.'
                  : 'Por onde você quer começar?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (_step == 0) ...[
              const Text(
                'Organize sua rotina, aprenda algo útil e transforme compromissos em conquistas.',
              ),
              const SizedBox(height: 16),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle_outline),
                title: Text('Construa uma rotina'),
                subtitle: Text(
                  'Escolha hábitos possíveis e registre seus dias.',
                ),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.menu_book_outlined),
                title: Text('Aprenda e pratique'),
                subtitle: Text(
                  'Siga aulas, faça anotações e aplique o que aprendeu.',
                ),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.flag_outlined),
                title: Text('Avance nos desafios'),
                subtitle: Text(
                  'Acompanhe seus registros e conquiste seus troféus.',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Escolher meu primeiro passo'),
              ),
            ] else ...[
              const Text(
                'Escolha um foco para abrir a área certa. Você pode mudar de ideia a qualquer momento.',
              ),
              const SizedBox(height: 16),
              for (final (focus, title, description, icon) in [
                (
                  WelcomeFocus.habits,
                  'Criar uma rotina',
                  'Escolher um hábito para hoje.',
                  Icons.check_circle_outline,
                ),
                (
                  WelcomeFocus.learning,
                  'Aprender algo novo',
                  'Explorar os programas e a primeira aula.',
                  Icons.menu_book_outlined,
                ),
                (
                  WelcomeFocus.challenges,
                  'Assumir um desafio',
                  'Conhecer as jornadas e escolher um compromisso.',
                  Icons.flag_outlined,
                ),
              ])
                Card(
                  child: ListTile(
                    selected: _focus == focus,
                    leading: Icon(icon),
                    title: Text(title),
                    subtitle: Text(description),
                    trailing: Icon(
                      _focus == focus
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    onTap: _finished
                        ? null
                        : () => setState(() => _focus = focus),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Sua conta está pronta. Escolha um primeiro passo; os demais recursos continuam disponíveis no menu.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _finished ? null : () => _finish(_focus),
                child: const Text('Ir para meu primeiro passo'),
              ),
              TextButton(
                onPressed: _finished ? null : () => setState(() => _step = 0),
                child: const Text('Voltar'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
