import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/auth_service.dart';
import '../widgets/official_hero_background.dart';
import '../widgets/pbh_logo.dart';

class SupabaseSetupScreen extends StatelessWidget {
  const SupabaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PbhLogo(),
                const SizedBox(height: 28),
                Text('Conecte o Supabase para ativar o login', style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('Configure a URL e a chave publicável do projeto com SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY no comando de build.', style: AppTextStyles.body, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_creatingAccount) {
        await AuthService().createAccount(_emailController.text, _passwordController.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta criada. Confirme seu e-mail pelo link enviado para entrar.')));
      } else {
        await AuthService().signIn(_emailController.text, _passwordController.text);
        if (mounted && widget.onClose != null) Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível concluir agora. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Informe seu e-mail no campo acima para receber o link.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().sendPasswordReset(email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Se esse e-mail estiver cadastrado, você receberá um link para redefinir a senha.')));
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível enviar o e-mail. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('already registered') || message.contains('already exists')) {
      return 'Este e-mail já possui uma conta.';
    }
    if (message.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (message.contains('password should be') || message.contains('at least')) {
      return 'Use uma senha com pelo menos 6 caracteres.';
    }
    if (message.contains('rate limit')) {
      return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
    }
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OfficialHeroBackground(
        animate: true,
        darken: .12,
        child: Stack(
          children: [
            const Positioned(right: -90, top: -110, child: _GlowCircle()),
            SafeArea(
              child: Stack(
                children: [
                  if (widget.onClose != null)
                    Positioned(
                      top: 4,
                      left: 12,
                      child: TextButton.icon(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Voltar para explorar'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        widget.onClose == null ? 32 : 66,
                        24,
                        28,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: PbhLogo()),
                            const SizedBox(height: 26),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: Column(
                                key: ValueKey(_creatingAccount),
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    _creatingAccount ? 'Comece sua jornada' : 'Bem-vindo de volta',
                                    style: AppTextStyles.headline.copyWith(fontSize: 27),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _creatingAccount
                                        ? 'Crie sua conta e construa uma rotina com propósito.'
                                        : 'Entre na sua conta para continuar sua jornada.',
                                    style: AppTextStyles.body,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(.96),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.borderSubtle),
                                boxShadow: [
                                  BoxShadow(color: AppColors.orange.withOpacity(.10), blurRadius: 36, spreadRadius: 2),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _AuthField(controller: _emailController, label: 'E-mail', hint: 'voce@exemplo.com', icon: Icons.alternate_email, keyboardType: TextInputType.emailAddress, validator: (value) => value == null || !value.trim().contains('@') ? 'Informe um e-mail válido.' : null),
                                    const SizedBox(height: 14),
                                    _AuthField(controller: _passwordController, label: 'Senha', hint: 'Mínimo de 6 caracteres', icon: Icons.lock_outline, obscureText: _obscurePassword, suffix: IconButton(tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha', onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textTertiary)), validator: (value) => value == null || value.length < 6 ? 'A senha deve ter ao menos 6 caracteres.' : null),
                                    if (!_creatingAccount)
                                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _loading ? null : _forgotPassword, child: const Text('Esqueci minha senha'))),
                                    if (_error != null) ...[
                                      const SizedBox(height: 8),
                                      Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.orange), textAlign: TextAlign.center),
                                    ],
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _loading ? null : _submit,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 180),
                                          child: _loading
                                              ? const SizedBox(key: ValueKey('loading'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                              : Text(_creatingAccount ? 'Criar conta' : 'Entrar', key: const ValueKey('label')),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: _loading ? null : () => setState(() {
                                _creatingAccount = !_creatingAccount;
                                _error = null;
                              }),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  _creatingAccount ? 'Já tem uma conta? Entrar' : 'Ainda não tem conta? Criar agora',
                                  key: ValueKey(_creatingAccount),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({required this.controller, required this.label, required this.hint, required this.icon, this.keyboardType, this.obscureText = false, this.suffix, this.validator});

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.statLabel),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            validator: validator,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
              suffixIcon: suffix,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderSubtle)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.orange)),
            ),
          ),
        ],
      );
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle();

  @override
  Widget build(BuildContext context) => Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.orange.withOpacity(.14), AppColors.orange.withOpacity(0)])));
}

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (_passwordController.text.length < 6) {
      setState(() => _error = 'A senha deve ter ao menos 6 caracteres.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'As senhas não coincidem.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService().updatePassword(_passwordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha atualizada. Entre com a nova senha.')));
        await AuthService().signOut();
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível atualizar a senha. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset_rounded, size: 54, color: AppColors.orange),
                  const SizedBox(height: 20),
                  Text('Crie uma nova senha', style: AppTextStyles.headline, textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  TextField(controller: _passwordController, obscureText: _obscure, decoration: InputDecoration(labelText: 'Nova senha', suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                  const SizedBox(height: 12),
                  TextField(controller: _confirmController, obscureText: _obscure, decoration: const InputDecoration(labelText: 'Confirme a nova senha')),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.orange)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _loading ? null : _savePassword, child: _loading ? const CircularProgressIndicator() : const Text('Salvar nova senha')),
                ],
              ),
            ),
          ),
        ),
      );
}
