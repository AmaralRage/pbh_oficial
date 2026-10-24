import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/auth_service.dart';
import '../services/notification_push_service.dart';
import 'blocked_members_screen.dart';
import 'profile_customization_screen.dart';
import '../widgets/animated_entry.dart';

class NotificationPreferences {
  NotificationPreferences._();

  static final SharedPreferencesAsync _storage = SharedPreferencesAsync();
  static String get _userKey =>
      Supabase.instance.client.auth.currentUser?.id ?? 'guest';
  static String get _enabledKey => 'pbh.notifications.$_userKey.enabled';
  static String get _soundKey => 'pbh.notifications.$_userKey.sound';

  static Future<bool> get enabled async =>
      await _storage.getBool(_enabledKey) ?? true;
  static Future<bool> get sound async =>
      await _storage.getBool(_soundKey) ?? true;

  static Future<void> setEnabled(bool value) =>
      _storage.setBool(_enabledKey, value);
  static Future<void> setSound(bool value) =>
      _storage.setBool(_soundKey, value);
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => const ProfileCustomizationScreen();
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _enabled = true;
  bool _sound = true;
  bool _loading = true;
  bool _pushBusy = false;
  String? _pushStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      NotificationPreferences.enabled,
      NotificationPreferences.sound,
    ]);
    if (mounted) {
      setState(() {
        _enabled = values[0];
        _sound = values[1];
        _loading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    await NotificationPreferences.setEnabled(value);
  }

  Future<void> _toggleSound(bool value) async {
    setState(() => _sound = value);
    await NotificationPreferences.setSound(value);
  }

  Future<void> _activatePush() async {
    setState(() {
      _pushBusy = true;
      _pushStatus = null;
    });
    try {
      await NotificationPushService.subscribe();
      if (mounted)
        setState(
          () => _pushStatus = kIsWeb
              ? 'Notificações ativadas neste navegador.'
              : 'Notificações ativadas neste celular.',
        );
    } catch (error) {
      if (mounted)
        setState(
          () => _pushStatus = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Unsupported operation: ', ''),
        );
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Notificações',
    subtitle: 'Escolha quais alertas aparecem enquanto você usa o app.',
    icon: Icons.notifications_none_rounded,
    children: [
      if (_loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(),
          ),
        )
      else ...[
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kIsWeb
                    ? 'Notificações no navegador'
                    : 'Notificações no celular',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                kIsWeb
                    ? 'Receba avisos mesmo quando o app estiver em segundo plano. O navegador pedirá sua permissão.'
                    : 'Receba avisos na barra de notificações, mesmo com o app fechado. O Android pedirá sua permissão.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pushBusy ? null : _activatePush,
                  icon: _pushBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_outlined),
                  label: Text(
                    _pushBusy
                        ? 'Cadastrando dispositivo...'
                        : 'Ativar neste dispositivo',
                  ),
                ),
              ),
              if (_pushStatus != null) ...[
                const SizedBox(height: 8),
                Text(
                  _pushStatus!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _pushStatus!.startsWith('Notificações ativadas')
                        ? context.pbhColors.orange
                        : context.pbhColors.textSecondary,
                  ),
                ),
              ],
              if (!NotificationPushService.isConfigured) ...[
                const SizedBox(height: 8),
                Text(
                  kIsWeb
                      ? 'A configuração de chave Web Push ainda está pendente no build do site.'
                      : 'A configuração de notificações Android ainda está pendente nesta versão do app.',
                  style: AppTextStyles.statLabel,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          child: Column(
            children: [
              _PreferenceSwitch(
                icon: Icons.notifications_active_outlined,
                title: 'Alertas no app',
                subtitle: 'Mostra o contador de avisos novos no sino.',
                value: _enabled,
                onChanged: _toggleEnabled,
              ),
              const Divider(height: 22),
              _PreferenceSwitch(
                icon: Icons.volume_up_outlined,
                title: 'Som de notificação',
                subtitle: _enabled
                    ? 'Toca quando um aviso novo chegar.'
                    : 'Ative os alertas para usar o som.',
                value: _sound,
                onChanged: _enabled ? _toggleSound : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Essas opções controlam os avisos dentro do app. O histórico continua disponível ao tocar no sino.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Versão ${const String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: 'desenvolvimento')} · build ${const String.fromEnvironment('FLUTTER_BUILD_NUMBER', defaultValue: 'local')}',
          style: AppTextStyles.statLabel,
        ),
      ],
    ],
  );
}

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _publicName = true;
  bool _shareProgress = false;
  bool _loading = true;
  bool _saving = false;
  String? _visibilityError;

  @override
  void initState() {
    super.initState();
    _loadVisibility();
  }

  Future<void> _loadVisibility() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null)
        throw StateError('Entre novamente para alterar sua privacidade.');
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('is_public,share_progress')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null)
        throw StateError('Não foi possível localizar seu perfil.');
      if (mounted)
        setState(() {
          _publicName = profile['is_public'] as bool? ?? true;
          _shareProgress = profile['share_progress'] as bool? ?? false;
          _loading = false;
          _visibilityError = null;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _visibilityError = error.toString().replaceFirst('Exception: ', '');
        });
    }
  }

  Future<void> _setPublicName(bool value) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final previous = _publicName;
    setState(() {
      _publicName = value;
      _saving = true;
      _visibilityError = null;
    });
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_public': value})
          .eq('id', userId);
    } catch (error) {
      if (mounted)
        setState(() {
          _publicName = previous;
          _visibilityError = error.toString().replaceFirst('Exception: ', '');
        });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setShareProgress(bool value) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final previous = _shareProgress;
    setState(() {
      _shareProgress = value;
      _saving = true;
      _visibilityError = null;
    });
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'share_progress': value})
          .eq('id', userId);
    } catch (_) {
      if (mounted)
        setState(() {
          _shareProgress = previous;
          _visibilityError =
              'Não foi possível salvar a visibilidade do progresso. Tente novamente.';
        });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendReset(BuildContext context) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await AuthService().sendPasswordReset(email);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enviamos um link de redefinição para seu e-mail.'),
          ),
        );
    } on AuthException catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _requestAccountDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Solicitar exclusão da conta?'),
        content: const Text(
          'O pedido será enviado ao suporte para processamento. Sua conta não será apagada automaticamente por este app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final user = Supabase.instance.client.auth.currentUser;
    final emailUri = Uri(
      scheme: 'mailto',
      path: AuthService.adminEmail,
      queryParameters: {
        'subject': 'Solicitação de exclusão de conta PBH Oficial',
        'body':
            'Solicito a exclusão da minha conta PBH Oficial.\nE-mail da conta: ${user?.email ?? 'não disponível'}',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir seu aplicativo de e-mail. Fale com o suporte pelo canal de ajuda.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['display_name'] as String?;
    return _SettingsPage(
      title: 'Privacidade',
      subtitle:
          'Controle como seu nome aparece na comunidade e proteja seu acesso.',
      icon: Icons.lock_outline_rounded,
      children: [
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visibilidade na comunidade',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Ao tornar o perfil privado, seu nome aparece como “Membro” no feed e outras pessoas não podem abrir seu perfil. Suas publicações e comentários continuam visíveis.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Perfil público'),
                  subtitle: Text(
                    _publicName
                        ? 'Nome, foto, biografia e capa ficam visíveis no seu perfil.'
                        : 'Seu nome aparece como Membro.',
                  ),
                  value: _publicName,
                  onChanged: _saving || _visibilityError != null
                      ? null
                      : _setPublicName,
                ),
              if (!_loading)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Compartilhar progresso e conquistas'),
                  subtitle: const Text(
                    'Permitir que outras pessoas vejam seus selos, títulos conquistados e números. Só aparece quando o perfil é público.',
                  ),
                  value: _shareProgress,
                  onChanged: _saving || !_publicName || _visibilityError != null
                      ? null
                      : _setShareProgress,
                ),
              if (_visibilityError != null) ...[
                Text(
                  _visibilityError!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.pbhColors.orange,
                  ),
                ),
                TextButton(
                  onPressed: _loadVisibility,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const BlockedMembersScreen(),
            ),
          ),
          icon: const Icon(Icons.block_outlined),
          label: const Text('Gerenciar membros bloqueados'),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dados da conta', style: AppTextStyles.titleMedium),
              const SizedBox(height: 14),
              _AccountDataRow(
                label: 'E-mail',
                value: user?.email ?? 'Não disponível',
              ),
              const SizedBox(height: 10),
              _AccountDataRow(
                label: 'Nome de exibição',
                value: name?.isNotEmpty == true ? name! : 'Não definido',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Segurança', style: AppTextStyles.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Redefina sua senha usando o link enviado ao e-mail da conta.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _sendReset(context),
                icon: const Icon(Icons.mark_email_read_outlined),
                label: const Text('Enviar link para redefinir senha'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'O nome e a descrição ficam nos metadados da conta. As publicações e comentários continuam no feed mesmo quando o nome fica oculto.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => _requestAccountDeletion(context),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Solicitar exclusão da conta'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.pbhColors.orange,
          ),
        ),
      ],
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _shareFeedback(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    final message =
        'Olá! Preciso de ajuda com o PBH Oficial.\n\n'
        'E-mail da conta: ${user?.email ?? 'não disponível'}\n'
        'Descreva aqui o que aconteceu: ';
    try {
      final emailUri = Uri(
        scheme: 'mailto',
        path: AuthService.adminEmail,
        queryParameters: {
          'subject': 'Ajuda com o PBH Oficial',
          'body': message,
        },
      );
      if (await canLaunchUrl(emailUri) && await launchUrl(emailUri)) return;
      await Share.share(message, subject: 'Ajuda com o PBH Oficial');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o menu de compartilhamento.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Ajuda e suporte',
    subtitle: 'Respostas rápidas para sua conta e notificações.',
    icon: Icons.help_outline_rounded,
    children: [
      _SettingsCard(
        child: Column(
          children: const [
            _HelpQuestion(
              title: 'Não consigo entrar. O que faço?',
              body:
                  'Confira se confirmou o e-mail de cadastro. Se esqueceu a senha, use “Esqueci minha senha” na tela de login.',
            ),
            Divider(height: 1),
            _HelpQuestion(
              title: 'Por que não ouvi o som do aviso?',
              body:
                  'O som toca com o app aberto e pode depender da permissão de áudio do navegador. Confira também se o som está ativado nas configurações de notificações.',
            ),
            Divider(height: 1),
            _HelpQuestion(
              title: 'Onde encontro avisos antigos?',
              body:
                  'Toque no sino no topo do app. O histórico fica disponível mesmo quando os alertas estão desativados.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _shareFeedback(context),
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Falar com o suporte'),
        ),
      ),
    ],
  );
}

class _HelpQuestion extends StatelessWidget {
  const _HelpQuestion({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 14),
    title: Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(body, style: AppTextStyles.bodySmall),
      ),
    ],
  );
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.pbhColors.background,
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        AnimatedEntry(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.pbhColors.featuredGradient,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.pbhColors.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.pbhColors.orangeDim,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: context.pbhColors.orange),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleLarge),
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ...children,
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.pbhColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.pbhColors.borderSubtle),
    ),
    child: child,
  );
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 180),
    opacity: onChanged == null ? .5 : 1,
    child: Row(
      children: [
        Icon(icon, color: context.pbhColors.orange, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _AccountDataRow extends StatelessWidget {
  const _AccountDataRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 120, child: Text(label, style: AppTextStyles.bodySmall)),
      Expanded(
        child: Text(
          value,
          style: AppTextStyles.body.copyWith(
            color: context.pbhColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}
