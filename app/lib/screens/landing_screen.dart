import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../admin/admin_screen.dart';
import '../auth/auth_controller.dart';
import '../state/app_controller.dart';
import '../theme.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key, required this.controller, required this.onStart});
  final AppController controller;
  final VoidCallback onStart;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.controller.displayName == 'Misafir' ? '' : widget.controller.displayName,
  );
  late String _gender     = widget.controller.gender;
  late String _peerGender = widget.controller.peerGender;

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  void _begin() {
    widget.controller.setProfile(
      name: _name.text.trim().isEmpty ? 'Misafir' : _name.text.trim(),
      gender: _gender,
      peerGender: _peerGender,
    );
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AzarBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, lc) {
              final hPad = lc.maxWidth > 720 ? 80.0 : 20.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: lc.maxHeight - 40),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(context),
                        const SizedBox(height: 32),
                        _hero(context).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                        const SizedBox(height: 28),
                        _formCard(context).animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.05),
                        const SizedBox(height: 24),
                        const Spacer(),
                        GradientButton(
                          label: 'EŞLEŞMEYE BAŞLA',
                          icon: Icons.bolt_rounded,
                          height: 60,
                          onTap: _begin,
                        ).animate().fadeIn(duration: 400.ms, delay: 240.ms).slideY(begin: 0.2),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Kamera ve mikrofon erişimi sorulacak',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
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

  Widget _header(BuildContext context) {
    final auth = AuthController.instance;
    return Row(
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            gradient: AzarPalette.brandGradient,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(color: AzarPalette.primary.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: -2),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text('kerochat', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: -0.3)),
        const Spacer(),
        if (auth.isModerator)
          _pillBtn(
            label: 'ADMIN',
            icon: Icons.shield_outlined,
            color: AzarPalette.secondary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminScreen()),
            ),
          ),
        const SizedBox(width: 8),
        _iconChip(
          icon: Icons.logout_rounded,
          onTap: () async => auth.signOut(),
        ),
      ],
    );
  }

  Widget _pillBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _iconChip({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: AzarPalette.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AzarPalette.line),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AzarPalette.textDim, size: 16),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final big = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: MediaQuery.of(context).size.width < 380 ? 40 : 52,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hazırsan', style: big),
        ShaderMask(
          shaderCallback: (b) => AzarPalette.brandGradient.createShader(b),
          child: Text(
            'eşleşelim.',
            style: big?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Tek tuşla rastgele biriyle görüntülü sohbet.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim),
        ),
      ],
    );
  }

  Widget _formCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('TAKMA AD'),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            maxLength: 24,
            style: const TextStyle(color: AzarPalette.text, fontSize: 15),
            cursorColor: AzarPalette.primary,
            decoration: InputDecoration(
              hintText: 'Misafir',
              hintStyle: const TextStyle(color: AzarPalette.textFaint),
              counterText: '',
              filled: true,
              fillColor: AzarPalette.surfaceHigh,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AzarPalette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AzarPalette.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AzarPalette.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _label('BEN'),
          const SizedBox(height: 8),
          _segment(
            value: _gender,
            options: const [('M', 'Erkek'), ('F', 'Kadın'), ('X', 'Belirtmem')],
            onChange: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 18),
          _label('KİMİNLE'),
          const SizedBox(height: 8),
          _segment(
            value: _peerGender,
            options: const [('any', 'Fark etmez'), ('M', 'Erkek'), ('F', 'Kadın')],
            onChange: (v) => setState(() => _peerGender = v),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(
        color: AzarPalette.textFaint,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ));

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
}
