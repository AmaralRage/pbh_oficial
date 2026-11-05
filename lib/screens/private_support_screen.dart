import 'package:flutter/material.dart';
import '../services/private_support_service.dart';
import 'support_history_screen.dart';

class PrivateSupportScreen extends StatefulWidget {
  const PrivateSupportScreen({super.key});
  @override
  State<PrivateSupportScreen> createState() => _PrivateSupportScreenState();
}

class _PrivateSupportScreenState extends State<PrivateSupportScreen> {
  final _message = TextEditingController();
  bool _sending = false;
  Future<void> _send() async {
    if (_sending || _message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await PrivateSupportService().submit(
        kind: 'help',
        message: _message.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensagem enviada à equipe do PBH.')),
      );
      _message.clear();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SupportHistoryScreen()),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível enviar. Tente novamente mais tarde.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Falar com o suporte')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Sua mensagem será recebida apenas pela equipe administrativa. Não envie senhas ou códigos de acesso.',
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _sending
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SupportHistoryScreen(),
                  ),
                ),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Meus pedidos e respostas'),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _message,
          enabled: !_sending,
          minLines: 5,
          maxLines: 10,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Como podemos ajudar?',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send_rounded),
          label: Text(_sending ? 'Enviando...' : 'Enviar mensagem'),
        ),
      ],
    ),
  );
}
