import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_controller.dart';
import '../atoms.dart';
import '../kc_context.dart';
import '../tokens.dart';

/// One-time 18+ confirmation gate (store policy). Shown right after signup,
/// before the app becomes usable. Declining signs the user out.
class KCAdultGate extends StatefulWidget {
  const KCAdultGate({super.key});
  @override
  State<KCAdultGate> createState() => _KCAdultGateState();
}

class _KCAdultGateState extends State<KCAdultGate> {
  bool _checked = false;
  bool _busy = false;

  Future<void> _confirm() async {
    final uid = AuthController.instance.userId;
    if (uid == null || !_checked || _busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'adult_confirmed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', uid);
      await AuthController.instance.loadProfile();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        KCContext.instance.toast('Bir hata oluştu, tekrar dene');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KC.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 92, height: 92,
                decoration: BoxDecoration(
                  color: KC.accentSoft, shape: BoxShape.circle,
                  border: Border.all(color: KC.accent.withValues(alpha: 0.45)),
                ),
                alignment: Alignment.center,
                child: Text('18+', style: kcSora(30, w: FontWeight.w800, color: KC.accent)),
              ),
              const SizedBox(height: 22),
              Text('Yaş doğrulaması', style: kcSora(24, w: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                'kerochat yalnızca 18 yaş ve üzeri kullanıcılar içindir. '
                'Devam etmek için yaşını onaylaman gerekiyor.',
                textAlign: TextAlign.center,
                style: kcManrope(14.5, color: KC.muted, height: 1.5),
              ),
              const SizedBox(height: 26),
              GestureDetector(
                onTap: () => setState(() => _checked = !_checked),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _checked ? KC.accentSoft : KC.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _checked ? KC.accent : KC.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: _checked ? KC.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: _checked ? KC.accent : KC.muted, width: 2),
                        ),
                        child: _checked
                            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('18 yaşından büyük olduğumu beyan ve onay ediyorum.',
                            style: kcManrope(14, w: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: _checked ? 1 : 0.45,
                child: KCButton(
                  label: _busy ? 'Kaydediliyor…' : 'Onayla ve devam et',
                  icon: Icons.arrow_forward_rounded,
                  onTap: _checked && !_busy ? _confirm : () {},
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await AuthController.instance.signOut();
                },
                child: Text('18 yaşından küçüğüm — çıkış yap',
                    style: kcManrope(13, w: FontWeight.w600, color: KC.muted)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
