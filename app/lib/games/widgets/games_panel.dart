import 'package:flutter/material.dart';

import '../../kc/atoms.dart';
import '../../kc/tokens.dart';
import '../game_controller.dart';
import 'hangman_game.dart';
import 'truth_dare_game.dart';
import 'xox_game.dart';

/// Full-screen-ish overlay that adapts to current GameController status.
/// Used by video_chat to render game UI on top of the call.
class KCGamesPanel extends StatefulWidget {
  const KCGamesPanel({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<KCGamesPanel> createState() => _KCGamesPanelState();
}

class _KCGamesPanelState extends State<KCGamesPanel> {
  final _gc = GameController.instance;

  @override
  void initState() {
    super.initState();
    _gc.addListener(_onChange);
  }

  @override
  void dispose() {
    _gc.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final s = _gc.status;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30, spreadRadius: 4)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              Container(width: 30, height: 30,
                decoration: BoxDecoration(
                  color: KC.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9)),
                alignment: Alignment.center,
                child: const Text('🎮', style: TextStyle(fontSize: 16))),
              const SizedBox(width: 10),
              Expanded(child: Text(_titleFor(s),
                style: kcSora(15, w: FontWeight.w700, color: Colors.white))),
              GestureDetector(
                onTap: () { _gc.quit(); widget.onClose(); },
                child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)),
              ),
            ]),
            const SizedBox(height: 16),
            // Body
            Flexible(child: SingleChildScrollView(child: _body(s))),
          ]),
        ),
      ),
    );
  }

  String _titleFor(GameStatus s) {
    switch (s) {
      case GameStatus.idle:           return 'Oyun seç';
      case GameStatus.inviteSent:     return '${_gc.activeGame?.label ?? 'Oyun'} — bekleniyor';
      case GameStatus.inviteReceived: return 'Oyun daveti';
      case GameStatus.playing:        return _gc.activeGame?.label ?? 'Oyun';
    }
  }

  Widget _body(GameStatus s) {
    switch (s) {
      case GameStatus.idle:           return _picker();
      case GameStatus.inviteSent:     return _waiting();
      case GameStatus.inviteReceived: return _incoming();
      case GameStatus.playing:        return _activeGame();
    }
  }

  Widget _picker() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final k in GameKind.values) ...[
        GestureDetector(
          onTap: () => _gc.invite(k),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
            child: Row(children: [
              Container(width: 42, height: 42,
                decoration: BoxDecoration(
                  color: KC.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(11)),
                alignment: Alignment.center,
                child: Text(k.emoji, style: const TextStyle(fontSize: 22))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k.label, style: kcSora(14.5, w: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(_descFor(k),
                  style: kcManrope(11.5, color: Colors.white.withValues(alpha: 0.65))),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }

  String _descFor(GameKind k) {
    switch (k) {
      case GameKind.xox:       return '3 sıralı klasik';
      case GameKind.hangman:   return 'Sen seç, karşı tahmin etsin';
      case GameKind.truthDare: return 'Sırayla kart çek';
    }
  }

  Widget _waiting() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 14),
      const CircularProgressIndicator(color: KC.accent, strokeWidth: 2.4),
      const SizedBox(height: 16),
      Text('Davet gönderildi, karşı taraf yanıtlıyor...',
        textAlign: TextAlign.center,
        style: kcManrope(13, color: Colors.white70)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => _gc.quit(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(10)),
          child: Text('Daveti geri çek',
            style: kcManrope(12.5, w: FontWeight.w600, color: Colors.white)),
        ),
      ),
    ]);
  }

  Widget _incoming() {
    final k = _gc.activeGame;
    if (k == null) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(k.emoji, style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 10),
      Text(k.label, style: kcSora(20, w: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 6),
      Text('Karşı taraf seninle oynamak istiyor',
        style: kcManrope(13, color: Colors.white70)),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(
          onTap: () => _gc.declineInvite(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(12)),
            child: Text('Reddet', style: kcSora(13.5, w: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _gc.acceptInvite(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: const BoxDecoration(gradient: KC.grad,
              borderRadius: BorderRadius.all(Radius.circular(12))),
            child: Text('Oyna', style: kcSora(13.5, w: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    ]);
  }

  Widget _activeGame() {
    switch (_gc.activeGame) {
      case GameKind.xox:       return const XoxGame();
      case GameKind.hangman:   return const HangmanGame();
      case GameKind.truthDare: return const TruthDareGame();
      case null:               return const SizedBox.shrink();
    }
  }
}
