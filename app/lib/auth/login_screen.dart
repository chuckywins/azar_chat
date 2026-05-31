import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  bool _showEmail = false;
  bool _isSignUp = true;
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() { _email.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _run(Future<void> Function() op) async {
    setState(() => _busy = true);
    await op();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: AzarBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, lc) {
              final hPad = lc.maxWidth > 720 ? 96.0 : 24.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: lc.maxHeight - 56),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _Logo().animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                        const SizedBox(height: 56),
                        _hero(context)
                            .animate()
                            .fadeIn(duration: 600.ms, delay: 100.ms)
                            .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                        const SizedBox(height: 40),
                        _ctaStack(c)
                            .animate()
                            .fadeIn(duration: 600.ms, delay: 300.ms)
                            .slideY(begin: 0.2, curve: Curves.easeOutCubic),
                        if (_showEmail) ...[
                          const SizedBox(height: 16),
                          _emailForm(c).animate().fadeIn(duration: 240.ms).slideY(begin: -0.05),
                        ],
                        if (c.lastError != null) ...[
                          const SizedBox(height: 16),
                          _errorBox(c.lastError!).animate().fadeIn().shake(hz: 3, duration: 360.ms),
                        ],
                        const Spacer(),
                        const SizedBox(height: 24),
                        Text(
                          '18+ uygulamadır. Devam ederek kullanım şartlarını ve gizlilik politikasını kabul etmiş sayılırsın.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (b) => AzarPalette.brandGradient.createShader(b),
          child: Text(
            'Tanış,\nKonuş,\nKaybol.',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width < 380 ? 44 : 56,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Rastgele insanlarla görüntülü konuş.\nİyi geçinmediysen tek tuşla sıradakine geç.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim),
        ),
      ],
    );
  }

  Widget _ctaStack(AuthController c) {
    return Column(
      children: [
        GradientButton(
          label: 'GOOGLE İLE DEVAM',
          icon: Icons.g_mobiledata_rounded,
          busy: _busy,
          onTap: () => _run(c.signInWithGoogle),
        ),
        const SizedBox(height: 12),
        GhostButton(
          label: _showEmail ? 'E-POSTAYI GİZLE' : 'E-POSTA İLE',
          icon: Icons.mail_outline_rounded,
          onTap: _busy ? null : () => setState(() => _showEmail = !_showEmail),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: AzarPalette.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('veya', style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(child: Container(height: 1, color: AzarPalette.line)),
          ],
        ),
        const SizedBox(height: 20),
        GhostButton(
          label: 'MİSAFİR OLARAK DEVAM',
          icon: Icons.person_outline_rounded,
          onTap: _busy ? null : () => _run(c.signInAnonymously),
        ),
      ],
    );
  }

  Widget _emailForm(AuthController c) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tab('GİRİŞ',  !_isSignUp, () => setState(() => _isSignUp = false)),
              const SizedBox(width: 24),
              _tab('KAYIT',   _isSignUp, () => setState(() => _isSignUp = true)),
            ],
          ),
          const SizedBox(height: 20),
          _input(_email, hint: 'eposta@ornek.com', keyboard: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _input(_pass, hint: 'şifre (en az 6 karakter)', obscure: true),
          const SizedBox(height: 18),
          GradientButton(
            label: _isSignUp ? 'HESAP OLUŞTUR' : 'GİRİŞ YAP',
            icon: Icons.arrow_forward_rounded,
            busy: _busy,
            onTap: () => _run(() => _isSignUp
                ? c.signUpWithEmail(_email.text.trim(), _pass.text)
                : c.signInWithEmail(_email.text.trim(), _pass.text)),
            height: 52,
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: active ? AzarPalette.text : AzarPalette.textFaint,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2, width: 44,
            decoration: BoxDecoration(
              gradient: active ? AzarPalette.brandGradient : null,
              color: active ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, {required String hint, bool obscure = false, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: AzarPalette.text, fontSize: 15),
      cursorColor: AzarPalette.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AzarPalette.textFaint),
        filled: true,
        fillColor: AzarPalette.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AzarPalette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AzarPalette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AzarPalette.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AzarPalette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AzarPalette.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AzarPalette.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg, style: const TextStyle(color: AzarPalette.text, fontSize: 13.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            gradient: AzarPalette.brandGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AzarPalette.primary.withValues(alpha: 0.4),
                blurRadius: 16, spreadRadius: -2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          'kerochat',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: -0.3),
        ),
      ],
    );
  }
}
