import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/pbh_palette.dart';
import '../services/appearance_service.dart';
import '../widgets/theme_choices.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});
  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late String _selected = AppearanceService.instance.palette.id;
  bool _saving = false;
  bool _effectsSaving = false;
  String? _error;
  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppearanceService.instance.apply(_selected);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível salvar o tema. Confira sua conexão e tente novamente.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.forPalette(
      PbhPalette.resolve(
        _selected,
        founder: AppearanceService.instance.founder,
      ),
    ),
    child: Builder(
      builder: (context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('Aparência do app')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'O PBH do seu jeito',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha as cores de todas as telas. Veja a prévia aqui e aplique quando gostar.',
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Efeitos reduzidos'),
                subtitle: const Text(
                  'Pausa animações decorativas e usa imagens estáticas nos troféus. Salvo neste aparelho.',
                ),
                value: AppearanceService.instance.reducedEffects,
                onChanged: _effectsSaving
                    ? null
                    : (value) async {
                        setState(() => _effectsSaving = true);
                        try {
                          await AppearanceService.instance.setReducedEffects(
                            value,
                          );
                        } catch (_) {
                          if (mounted)
                            setState(
                              () => _error =
                                  'Não foi possível salvar a preferência de efeitos.',
                            );
                        } finally {
                          if (mounted) setState(() => _effectsSaving = false);
                        }
                      },
              ),
              const SizedBox(height: 12),
              ThemeChoices(
                selected: _selected,
                founder: AppearanceService.instance.founder,
                onSelected: _saving
                    ? null
                    : (id) => setState(() => _selected = id),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!),
                ),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.palette_outlined),
                label: Text(_saving ? 'Salvando…' : 'Aplicar tema'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Você pode definir outro tema só para o perfil em Editar perfil.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
