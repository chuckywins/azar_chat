import 'package:flutter/material.dart';

import '../theme.dart';
import 'auth_controller.dart';

/// First-launch screen.  Three paths: Misafir (anonymous), Google, Email.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  bool _showEmail = false;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() op) async {
    setState(() => _busy = true);
    await op();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, lc) {
            final wide = lc.maxWidth > 720;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(wide ? 64 : 24, 24, wide ? 64 : 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: lc.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 12, height: 12, color: AzarPalette.accent),
                          const SizedBox(width: 10),
                          Text('kerochat', style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text('Hoş geldin.',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: MediaQuery.of(context).size.width < 380 ? 44 : 56,
                              )),
                      const SizedBox(height: 12),
                      Text(
                        'Devam etmek için bir yöntem seç. Misafir hızlı, kayıt kalıcı.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim),
                      ),
                      const SizedBox(height: 40),

                      _PrimaryBtn(
                        label: 'GOOGLE İLE DEVAM',
                        icon: Icons.g_mobiledata_rounded,
                        onTap: _busy ? null : () => _run(c.signInWithGoogle),
                      ),
                      const SizedBox(height: 12),
                      _SecondaryBtn(
                        label: _showEmail ? 'E-postayı gizle' : 'E-POSTA İLE',
                        icon: Icons.mail_outline,
                        onTap: _busy ? null : () => setState(() => _showEmail = !_showEmail),
                      ),

                      if (_showEmail) ...[
                        const SizedBox(height: 16),
                        _emailForm(context),
                      ],

                      const SizedBox(height: 28),
                      _divider(context),
                      const SizedBox(height: 28),

                      _SecondaryBtn(
                        label: 'MİSAFİR OLARAK DEVAM',
                        icon: Icons.person_outline,
                        onTap: _busy ? null : () => _run(c.signInAnonymously),
                      ),

                      if (c.lastError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border.all(color: AzarPalette.danger)),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, color: AzarPalette.danger),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(c.lastError!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AzarPalette.text)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Spacer(),

                      Text(
                        '18+ uygulamadır. Devam ederek kullanım şartlarını ve gizlilik politikasını kabul etmiş sayılırsın.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _emailForm(BuildContext context) {
    final c = widget.controller;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AzarPalette.surface, border: Border.all(color: AzarPalette.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSignUp = false),
                  child: Text('GİRİŞ',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _isSignUp ? AzarPalette.textDim : AzarPalette.accent,
                            letterSpacing: 1.5,
                          )),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSignUp = true),
                  child: Text('KAYIT',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _isSignUp ? AzarPalette.accent : AzarPalette.textDim,
                            letterSpacing: 1.5,
                          )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: Theme.of(context).textTheme.bodyLarge,
            cursorColor: AzarPalette.accent,
            decoration: const InputDecoration(
              hintText: 'eposta@ornek.com',
              isDense: true,
              border: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.accent, width: 2)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            style: Theme.of(context).textTheme.bodyLarge,
            cursorColor: AzarPalette.accent,
            decoration: const InputDecoration(
              hintText: 'şifre',
              isDense: true,
              border: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.accent, width: 2)),
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryBtn(
            label: _isSignUp ? 'HESAP OLUŞTUR' : 'GİRİŞ YAP',
            icon: Icons.arrow_forward,
            onTap: _busy
                ? null
                : () => _run(() => _isSignUp
                    ? c.signUpWithEmail(_email.text.trim(), _pass.text)
                    : c.signInWithEmail(_email.text.trim(), _pass.text)),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AzarPalette.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('veya', style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Container(height: 1, color: AzarPalette.line)),
      ],
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(color: disabled ? AzarPalette.surfaceUp : AzarPalette.accent),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: disabled ? AzarPalette.textDim : AzarPalette.bg, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: disabled ? AzarPalette.textDim : AzarPalette.bg,
                      letterSpacing: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AzarPalette.surface,
            border: Border.all(color: AzarPalette.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AzarPalette.text, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}
