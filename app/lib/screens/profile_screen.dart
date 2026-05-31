import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _nick = TextEditingController(text: AuthController.instance.profile?.nickname ?? '');
  late String _gender = AuthController.instance.profile?.gender ?? 'X';
  bool _busy = false;
  String? _msg;
  bool _msgIsError = false;

  @override
  void dispose() { _nick.dispose(); super.dispose(); }

  Future<void> _save() async {
    final uid = AuthController.instance.userId;
    if (uid == null) return;
    setState(() { _busy = true; _msg = null; });
    try {
      await Supabase.instance.client.from('profiles').update({
        'nickname': _nick.text.trim().isEmpty ? null : _nick.text.trim(),
        'gender': _gender,
      }).eq('id', uid);
      await AuthController.instance.loadProfile();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _msgIsError = false;
        _msg = 'Profil güncellendi';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _msgIsError = true;
        _msg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _signOut() async {
    await AuthController.instance.signOut();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AzarPalette.surfaceGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AzarPalette.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AzarPalette.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.delete_outline_rounded, color: AzarPalette.danger, size: 22),
              ),
              const SizedBox(height: 14),
              Text('Hesabı silmek istediğine emin misin?', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Profilin, yasak geçmişin ve raporların kalıcı olarak silinir. Geri alınamaz.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: GhostButton(label: 'Vazgeç', onTap: () => Navigator.pop(ctx, false), height: 44)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientButton(
                      label: 'EVET, SİL',
                      onTap: () => Navigator.pop(ctx, true),
                      gradient: const LinearGradient(colors: [AzarPalette.danger, Color(0xFFFF7A8A)]),
                      height: 44,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final uid = AuthController.instance.userId;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      // RLS allows user to delete own profile via cascade; auth.users still exists,
      // but profile cascade removes ban/report history.  Full auth delete requires Edge Function.
      await Supabase.instance.client.from('profiles').delete().eq('id', uid);
      await AuthController.instance.signOut();
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _msgIsError = true;
        _msg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.instance;
    final isAnon = auth.isAnonymous;
    final user = auth.user;
    final displayInitial = (_nick.text.isNotEmpty ? _nick.text : (auth.displayName ?? 'M')).substring(0, 1).toUpperCase();

    return Scaffold(
      body: AzarBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              // Top bar
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AzarPalette.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AzarPalette.line),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_rounded, color: AzarPalette.text, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Profil', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),

              const SizedBox(height: 28),

              // Big avatar
              Center(
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    gradient: AzarPalette.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AzarPalette.primary.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 2),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayInitial,
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.85, 0.85)),

              const SizedBox(height: 14),
              Center(
                child: Text(
                  isAnon ? 'Misafir hesabı' : (user?.email ?? '-'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),

              const SizedBox(height: 28),

              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('TAKMA AD'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nick,
                      maxLength: 24,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AzarPalette.text, fontSize: 15),
                      cursorColor: AzarPalette.primary,
                      decoration: _inputDeco('Misafir'),
                    ),
                    const SizedBox(height: 18),
                    _label('CİNSİYET'),
                    const SizedBox(height: 8),
                    _segment(
                      value: _gender,
                      options: const [('M', 'Erkek'), ('F', 'Kadın'), ('X', 'Belirtmem')],
                      onChange: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 18),
                    GradientButton(label: 'KAYDET', icon: Icons.check_rounded, busy: _busy, onTap: _save),
                  ],
                ),
              ),

              if (_msg != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_msgIsError ? AzarPalette.danger : AzarPalette.success).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (_msgIsError ? AzarPalette.danger : AzarPalette.success).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _msgIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                        color: _msgIsError ? AzarPalette.danger : AzarPalette.success,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_msg!, style: const TextStyle(color: AzarPalette.text, fontSize: 13.5))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Account actions
              _sectionTitle('HESAP'),
              const SizedBox(height: 10),
              _actionRow(icon: Icons.logout_rounded, label: 'Çıkış yap', onTap: _signOut),
              const SizedBox(height: 8),
              _actionRow(
                icon: Icons.delete_outline_rounded,
                label: 'Hesabı sil',
                danger: true,
                onTap: _confirmDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(color: AzarPalette.textFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5));

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(color: AzarPalette.textFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AzarPalette.textFaint),
        counterText: '',
        filled: true,
        fillColor: AzarPalette.surfaceHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AzarPalette.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AzarPalette.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AzarPalette.primary, width: 1.5)),
      );

  Widget _segment({required String value, required List<(String, String)> options, required ValueChanged<String> onChange}) {
    return Row(
      children: options.map((o) {
        final selected = o.$1 == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChange(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected ? AzarPalette.brandGradient : null,
                  color: selected ? null : AzarPalette.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? Colors.transparent : AzarPalette.line),
                ),
                child: Text(
                  o.$2,
                  style: TextStyle(
                    color: selected ? Colors.white : AzarPalette.textDim,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _actionRow({required IconData icon, required String label, required VoidCallback onTap, bool danger = false}) {
    final color = danger ? AzarPalette.danger : AzarPalette.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AzarPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: danger ? AzarPalette.danger.withValues(alpha: 0.4) : AzarPalette.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.6), size: 18),
          ],
        ),
      ),
    );
  }
}
