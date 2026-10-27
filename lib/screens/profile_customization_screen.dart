import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart' as files;
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/profile_style.dart';
import '../services/auth_service.dart';
import '../services/profile_customization_service.dart';
import '../widgets/profile_identity_card.dart';
import '../widgets/profile_theme_scope.dart';
import '../widgets/theme_choices.dart';
import '../widgets/profile_effect_picker.dart';

class ProfileCustomizationScreen extends StatefulWidget {
  const ProfileCustomizationScreen({super.key});
  @override
  State<ProfileCustomizationScreen> createState() =>
      _ProfileCustomizationScreenState();
}

class _ProfileCustomizationScreenState
    extends State<ProfileCustomizationScreen> {
  final _service = ProfileCustomizationService();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  late ProfileStyle _style;
  ProfileStyle? _savedStyle;
  ProfileUnlocks? _unlocks;
  String? _avatar;
  Uint8List? _photo;
  String? _coverUrl;
  Uint8List? _coverPhoto;
  bool _removeCover = false;
  bool get _customCover =>
      _coverPhoto != null || (!_removeCover && _coverUrl?.isNotEmpty == true);
  bool _removePhoto = false;
  bool _saving = false;
  bool _picking = false;
  bool _loading = true;
  String _section = 'profile';
  final _editorKey = GlobalKey();
  final _scrollController = ScrollController();
  String? _error;
  late final bool _founder;
  late final String? _account;
  @override
  void initState() {
    super.initState();
    final user = _service.client.auth.currentUser;
    _account = user?.id;
    final data = user?.userMetadata ?? {};
    _founder = AuthService.isProjectLeader(user);
    _name.text = data['display_name'] as String? ?? (_founder ? 'Amaral' : '');
    _bio.text = data['bio'] as String? ?? '';
    _avatar = data['avatar_url'] as String?;
    _coverUrl = data['cover_url'] as String?;
    _style = ProfileStyle.fromMetadata(data, founder: _founder);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final unlocks = await _service.unlocks();
      if (!mounted) return;
      setState(() {
        _unlocks = unlocks;
        _style = _style.validated(
          founder: _founder,
          completed: unlocks.completed,
          earned: unlocks.earned,
        );
        _savedStyle ??= _style;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível carregar suas conquistas. Tente novamente.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick({bool cover = false}) async {
    setState(() => _picking = true);
    try {
      final file = cover
          ? await files.openFile(
              acceptedTypeGroups: [
                const files.XTypeGroup(
                  label: 'Capas',
                  extensions: [
                    'png',
                    'jpg',
                    'jpeg',
                    'webp',
                    'gif',
                    'html',
                    'htm',
                  ],
                  uniformTypeIdentifiers: ['public.image', 'public.html'],
                ),
              ],
            )
          : await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: cover ? 1600 : 1024,
              maxHeight: cover ? 900 : 1024,
              imageQuality: 85,
              requestFullMetadata: false,
            );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024)
        throw ArgumentError('Escolha uma imagem de até 5 MB.');
      final bytes = await file.readAsBytes();
      final type = cover
          ? ProfileCustomizationService.coverType(bytes)
          : ProfileCustomizationService.imageType(bytes);
      if (type != 'html') {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 256,
          allowUpscaling: false,
        );
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      }
      if (!mounted) return;
      setState(() {
        if (cover) {
          _coverPhoto = bytes;
          _removeCover = false;
        } else {
          _photo = bytes;
          _removePhoto = false;
        }
        _error = null;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = cover
              ? 'Não foi possível abrir a capa. Use PNG, JPEG, WebP, GIF ou HTML completo em UTF-8, até 5 MB.'
              : 'Não foi possível abrir a imagem. Use PNG, JPEG ou WebP de até 5 MB.',
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_account != _service.client.auth.currentUser?.id) {
      setState(() => _error = 'A conta mudou. Reabra o editor do perfil.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.save(
        name: _name.text,
        bio: _bio.text,
        style: _style,
        photo: _photo,
        removePhoto: _removePhoto,
        coverPhoto: _coverPhoto,
        removeCover: _removeCover,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível salvar. Confira a conexão, o nome e as imagens e tente novamente. Suas escolhas continuam aqui.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Widget _heading(String label) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Text(label, style: AppTextStyles.titleMedium),
  );
  Widget _profilePreview(ProfileUnlocks progress, {bool editable = true}) =>
      ProfileThemeScope(
        themeId: _style.profileTheme,
        founder: _founder,
        builder: (context) => ProfileIdentityCard(
          name: _name.text.trim().isEmpty ? 'Seu nome' : _name.text.trim(),
          bio: _bio.text.trim(),
          style: _style,
          earned: progress.earned,
          founder: _founder,
          photo: _photo,
          avatarUrl: _removePhoto ? null : _avatar,
          coverPhoto: _coverPhoto,
          coverUrl: _removeCover ? null : _coverUrl,
          onEditCover: editable && !_saving && !_picking
              ? () => _openSection('cover')
              : null,
          onEditPhoto: editable && !_saving && !_picking
              ? () => _openSection('photo')
              : null,
        ),
      );
  Future<void> _enlargePreview(ProfileUnlocks progress) => showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prévia do perfil'),
          leading: IconButton(
            tooltip: 'Fechar prévia',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Use dois dedos ou o gesto de zoom para ampliar.'),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 2.5,
                child: Center(
                  child: SingleChildScrollView(
                    child: _profilePreview(progress, editable: false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void _openSection(String section) {
    FocusScope.of(context).unfocus();
    setState(() => _section = section);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _editorKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        alignment: 0,
      );
    });
  }

  void _restoreAppearance() {
    if (_savedStyle == null) return;
    setState(() {
      _style = _savedStyle!;
      _photo = null;
      _coverPhoto = null;
      _removePhoto = false;
      _removeCover = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alterações da aparência desfeitas.')),
    );
  }

  Widget _intensity({required bool frame}) {
    final value = frame ? _style.frameIntensity : _style.coverIntensity;
    final label = frame ? 'Intensidade da moldura' : 'Intensidade da capa';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          '$label · ${(value * 100).round()}%',
          style: AppTextStyles.bodySmall,
        ),
        Slider(
          semanticFormatterCallback: (v) => '${(v * 100).round()} por cento',
          value: value,
          divisions: 10,
          label: '${(value * 100).round()}%',
          onChanged: _saving
              ? null
              : (v) => setState(() {
                  _style = frame
                      ? _style.copyWith(frameIntensity: v)
                      : _style.copyWith(coverIntensity: v);
                }),
        ),
        Text(
          'Suave → intenso. Ajusta a velocidade, o brilho ou a quantidade de elementos conforme o efeito.',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }

  Widget _options(
    List<ProfileStyleOption> options,
    String value,
    ValueChanged<String> select,
  ) {
    final ids = _unlocks!.earned.map((e) => e.id).toSet();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final available = option.available(_founder, _unlocks!.completed, ids);
        return Tooltip(
          message: available ? option.label : option.requirement,
          child: ChoiceChip(
            selected: value == option.id,
            labelStyle: TextStyle(
              color: value == option.id
                  ? context.pbhColors.onAccent
                  : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            avatar: Icon(
              available ? Icons.circle : Icons.lock_outline,
              size: 15,
              color: option.color,
            ),
            label: Text(
              available
                  ? option.label
                  : '${option.label} · ${option.requirement}',
            ),
            onSelected: available && !_saving
                ? (_) => setState(() => select(option.id))
                : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _unlocks;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Personalizar perfil'),
          actions: [
            if (!_loading && progress != null)
              IconButton(
                tooltip: 'Voltar à prévia',
                icon: const Icon(Icons.preview_outlined),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : progress == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error ?? 'Perfil indisponível.'),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text('Sua identidade no PBH', style: AppTextStyles.headline),
                  const SizedBox(height: 8),
                  Text(
                    'Escolha como sua história aparece no perfil.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  _profilePreview(progress),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _enlargePreview(progress),
                          icon: const Icon(Icons.zoom_in),
                          label: const Text('Ampliar prévia'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        onPressed: _saving || _picking
                            ? null
                            : _restoreAppearance,
                        icon: const Icon(Icons.undo),
                        tooltip: 'Restaurar aparência salva',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    key: _editorKey,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in const [
                        ('profile', 'Perfil', Icons.person_outline),
                        ('photo', 'Foto', Icons.account_circle_outlined),
                        ('cover', 'Capa', Icons.wallpaper_rounded),
                        ('badges', 'Selos', Icons.workspace_premium_outlined),
                      ])
                        ChoiceChip(
                          selected: _section == item.$1,
                          showCheckmark: false,
                          avatar: Icon(
                            item.$3,
                            size: 18,
                            color: _section == item.$1
                                ? context.pbhColors.onAccent
                                : Colors.white,
                          ),
                          label: Text(item.$2),
                          labelStyle: TextStyle(
                            color: _section == item.$1
                                ? context.pbhColors.onAccent
                                : Colors.white,
                          ),
                          onSelected: _saving || _picking
                              ? null
                              : (_) => setState(() => _section = item.$1),
                        ),
                    ],
                  ),
                  if (_section == 'photo') ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _saving || _picking ? null : () => _pick(),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(_picking ? 'Abrindo…' : 'Escolher foto'),
                        ),
                        if (_photo != null || _avatar?.isNotEmpty == true)
                          TextButton(
                            onPressed: _saving || _picking
                                ? null
                                : () => setState(() {
                                    _photo = null;
                                    _removePhoto = true;
                                  }),
                            child: const Text('Restaurar foto padrão'),
                          ),
                      ],
                    ),
                    Text(
                      'A foto fica visível nas suas publicações quando seu perfil é público.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                  if (_section == 'profile') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      enabled: !_saving,
                      maxLength: 40,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome de exibição',
                      ),
                    ),
                    TextField(
                      controller: _bio,
                      enabled: !_saving,
                      maxLength: 120,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Sobre você',
                      ),
                    ),
                    _heading('Tema do perfil'),
                    ThemeChoices(
                      selected: _style.profileTheme,
                      founder: _founder,
                      allowFollowApp: true,
                      onSelected: _saving
                          ? null
                          : (id) => setState(
                              () => _style = _style.copyWith(profileTheme: id),
                            ),
                    ),
                  ],
                  if (_section == 'photo') ...[
                    _heading('Moldura da foto'),
                    _options(
                      ProfileStyle.frames,
                      _style.frame,
                      (id) => _style = _style.copyWith(frame: id),
                    ),
                    _heading('Animação da moldura'),
                    ProfileEffectPicker(
                      options: ProfileStyle.frameEffects,
                      selected: _style.frameEffect,
                      optionsBuilder: (options) => _options(
                        options,
                        _style.frameEffect,
                        (id) => _style = _style.copyWith(frameEffect: id),
                      ),
                    ),
                    if (ProfileStyle.hasIntensity(_style.frameEffect))
                      _intensity(frame: true),
                  ],
                  if (_section == 'cover') ...[
                    _heading('Capa do perfil'),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving || _picking
                              ? null
                              : () => _pick(cover: true),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Enviar minha capa'),
                        ),
                        if (_customCover)
                          TextButton(
                            onPressed: _saving || _picking
                                ? null
                                : () => setState(() {
                                    _coverPhoto = null;
                                    _removeCover = true;
                                  }),
                            child: const Text('Usar capa do PBH'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PNG, JPEG, WebP, GIF animado ou arte HTML, até 5 MB. O HTML deve conter suas imagens e estilos no próprio arquivo. Os efeitos continuam sobre a capa.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _options(
                      ProfileStyle.covers,
                      _customCover ? '' : _style.cover,
                      (id) {
                        _style = _style.copyWith(
                          cover: id,
                          coverEffect: id == 'bonfire' ? 'embers' : null,
                        );
                        _coverPhoto = null;
                        _removeCover = true;
                      },
                    ),
                    _heading('Animação sobre a capa'),
                    Text(
                      'Os efeitos também aparecem sobre a sua capa enviada. Veja a prévia no topo.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ProfileEffectPicker(
                      options: ProfileStyle.coverEffects,
                      selected: _style.coverEffect,
                      optionsBuilder: (options) => _options(
                        options,
                        _style.coverEffect,
                        (id) => _style = _style.copyWith(coverEffect: id),
                      ),
                    ),
                    if (_founder && _style.coverEffect == 'legacy') ...[
                      _heading('Variante da nebulosa'),
                      _options(
                        ProfileStyle.nebulaVariants,
                        _style.coverVariant,
                        (id) => _style = _style.copyWith(coverVariant: id),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _style.coverVariant == 'astral'
                            ? 'Auroras verticais, arcos de plasma e partículas ascendentes.'
                            : _style.coverVariant == 'eclipse'
                            ? 'Ondas de âmbar, magenta e violeta com estrelas cintilantes.'
                            : 'Nuvens e ondas de roxo, azul e ciano com estrelas cintilantes.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                    if (ProfileStyle.hasIntensity(_style.coverEffect))
                      _intensity(frame: false),
                  ],
                  if (_section == 'badges') ...[
                    _heading('Título'),
                    DropdownButtonFormField<String>(
                      initialValue: _style.title,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: 'member',
                          child: Text('Membro do PBH'),
                        ),
                        if (_founder)
                          const DropdownMenuItem(
                            value: 'founder',
                            child: Text('Fundador do PBH'),
                          ),
                        for (final badge in progress.earned)
                          DropdownMenuItem(
                            value: badge.id,
                            child: Text(
                              badge.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _style = _style.copyWith(title: value),
                            ),
                    ),
                    _heading('Selos em destaque'),
                    Text(
                      'Escolha até 3. A ordem de seleção será a ordem da sua vitrine.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (progress.earned.isEmpty)
                      Text(
                        'Conclua desafios para conquistar seus primeiros selos.',
                        style: AppTextStyles.bodySmall,
                      ),
                    for (final badge in progress.earned)
                      Builder(
                        builder: (_) {
                          final selected = _style
                              .highlights(progress.earned)
                              .map((e) => e.id)
                              .toList();
                          final index = selected.indexOf(badge.id);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(badge.icon, color: badge.color),
                            title: Text(badge.title),
                            subtitle: index < 0
                                ? null
                                : Text('Destaque ${index + 1}'),
                            value: index >= 0,
                            onChanged: _saving
                                ? null
                                : (value) {
                                    if (value == true && selected.length >= 3) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Remova um selo para escolher outro. O limite é 3.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() {
                                      value == true
                                          ? selected.add(badge.id)
                                          : selected.remove(badge.id);
                                      _style = _style.copyWith(
                                        featured: selected,
                                      );
                                    });
                                  },
                          );
                        },
                      ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.pbhColors.orange,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _saving || _picking ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Salvando…' : 'Salvar perfil'),
                  ),
                ],
              ),
      ),
    );
  }
}
