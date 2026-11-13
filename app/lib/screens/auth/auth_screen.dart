import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool isLogin = true;
  bool busy = false;
  bool obscure = true;

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    final auth = ref.read(authProvider.notifier);
    _run(() => isLogin
        ? auth.login(emailCtrl.text.trim(), passCtrl.text)
        : auth.register(emailCtrl.text.trim(), passCtrl.text, nameCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Декоративные градиентные пятна
          Positioned(
            top: -120,
            right: -80,
            child: _orb(WpColors.primaryBright.withValues(alpha: .18), 320),
          ),
          Positioned(
            bottom: -100,
            left: -90,
            child: _orb(WpColors.teal.withValues(alpha: .16), 280),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: LogoMark(size: 72)).animate().scale(
                          duration: 600.ms, curve: Curves.easeOutBack, begin: const Offset(.7, .7)),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          isLogin ? 'С возвращением!' : 'Создать аккаунт',
                          style: text.headlineMedium,
                        ),
                      ).animate(key: ValueKey(isLogin)).fadeIn(duration: 350.ms).slideY(begin: .2),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          isLogin
                              ? 'Войдите, чтобы продолжить планировать'
                              : 'Пара секунд — и ИИ спланирует вашу поездку',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              child: isLogin
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: TextFormField(
                                        controller: nameCtrl,
                                        textCapitalization: TextCapitalization.words,
                                        decoration: const InputDecoration(
                                          hintText: 'Имя',
                                          prefixIcon: Icon(Icons.person_rounded),
                                        ),
                                      ),
                                    ),
                            ),
                            TextFormField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                hintText: 'Email',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                              validator: (v) =>
                                  v != null && v.contains('@') ? null : 'Введите корректный email',
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passCtrl,
                              obscureText: obscure,
                              decoration: InputDecoration(
                                hintText: 'Пароль',
                                prefixIcon: const Icon(Icons.lock_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                  onPressed: () => setState(() => obscure = !obscure),
                                ),
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) =>
                                  v != null && v.length >= 6 ? null : 'Минимум 6 символов',
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: busy ? null : _submit,
                              child: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : Text(isLogin ? 'Войти' : 'Зарегистрироваться'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => _run(() => ref.read(authProvider.notifier).guest()),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('Продолжить как гость'),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => isLogin = !isLogin),
                          child: Text.rich(
                            TextSpan(
                              text: isLogin ? 'Нет аккаунта?  ' : 'Уже есть аккаунт?  ',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                              children: [
                                TextSpan(
                                  text: isLogin ? 'Создать' : 'Войти',
                                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: .05, curve: Curves.easeOutCubic),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}
