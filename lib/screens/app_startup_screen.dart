import 'dart:async';

import 'package:flutter/material.dart';

/// Paint the first frame before waiting on platform storage and authentication.
class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({
    super.key,
    required this.initialize,
    required this.child,
  });
  final Future<void> Function() initialize;
  final Widget child;

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  bool _ready = false;
  bool _failed = false;
  bool _slow = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _slow = true);
    });
    try {
      await widget.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (error, stackTrace) {
      debugPrint('PBH startup failed: $error');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 8);
      if (mounted) setState(() => _failed = true);
    } finally {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF6B00),
                  size: 52,
                ),
                const SizedBox(height: 20),
                Text(
                  _failed
                      ? 'Não foi possível iniciar o PBH'
                      : 'Abrindo PBH Oficial…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 20),
                if (_failed) ...[
                  const Text(
                    'Tente novamente. Seus dados salvos serão mantidos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _failed = false;
                        _slow = false;
                      });
                      _initialize();
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ] else ...[
                  const CircularProgressIndicator(color: Color(0xFFFF6B00)),
                  if (_slow) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'A abertura está demorando mais que o esperado. Aguarde a recuperação da sua sessão.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
