import 'package:flutter/material.dart';

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
  late String _gender = widget.controller.gender;
  late String _peerGender = widget.controller.peerGender;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 720;
            final hPad = wide ? 64.0 : 20.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 44),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context),
                      const SizedBox(height: 36),
                      _hero(context),
                      const SizedBox(height: 28),
                      _formCard(context),
                      const SizedBox(height: 28),
                      const Spacer(),
                      _startButton(context),
                      const SizedBox(height: 12),
                      Text(
                        'Devam ederek kamera ve mikrofon erişimini onaylıyorsun. 18+ uygulamadır.',
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

  Widget _header(BuildContext context) {
    final auth = AuthController.instance;
    return Row(
      children: [
        Container(width: 12, height: 12, color: AzarPalette.accent),
        const SizedBox(width: 10),
        Text('kerochat', style: Theme.of(context).textTheme.labelLarge),
        const Spacer(),
        if (auth.isModerator)
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(border: Border.all(color: AzarPalette.accent)),
              child: Text('ADMIN',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AzarPalette.accent,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      )),
            ),
          )
        else
          Text('v0.2', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () async {
            await auth.signOut();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Icon(Icons.logout, size: 14, color: AzarPalette.textDim),
          ),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    final display = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: MediaQuery.of(context).size.width < 380 ? 44 : 56,
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rastgele', style: display),
          Text(
            'biriyle\nkonuş.',
            style: display?.copyWith(color: AzarPalette.accent),
          ),
          const SizedBox(height: 20),
          Text(
            'Eşleş, görüntülü konuş, beğenmezsen sıradakine geç. Hesap yok, profil yok.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AzarPalette.textDim),
          ),
        ],
      ),
    );
  }

  Widget _formCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AzarPalette.surface,
        border: Border.all(color: AzarPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Takma ad'),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            maxLength: 24,
            style: Theme.of(context).textTheme.bodyLarge,
            cursorColor: AzarPalette.accent,
            decoration: const InputDecoration(
              hintText: 'Misafir',
              counterText: '',
              isDense: true,
              border: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.line)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AzarPalette.accent, width: 2)),
            ),
          ),
          const SizedBox(height: 20),
          _label('Ben'),
          const SizedBox(height: 8),
          _segment(
            value: _gender,
            options: const [('M', 'Erkek'), ('F', 'Kadın'), ('X', 'Belirtmem')],
            onChange: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 20),
          _label('Kiminle eşleşeyim'),
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

  Widget _label(String text) => Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2),
      );

  Widget _segment({
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChange,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final selected = o.$1 == value;
        return GestureDetector(
          onTap: () => onChange(o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AzarPalette.accent : AzarPalette.surfaceUp,
              border: Border.all(color: selected ? AzarPalette.accent : AzarPalette.line),
            ),
            child: Text(
              o.$2,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? AzarPalette.bg : AzarPalette.text,
                  ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _startButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _begin,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: const BoxDecoration(color: AzarPalette.accent),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'EŞLEŞMEYE BAŞLA',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AzarPalette.bg,
                      letterSpacing: 2,
                      fontSize: 16,
                    ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, color: AzarPalette.bg, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
