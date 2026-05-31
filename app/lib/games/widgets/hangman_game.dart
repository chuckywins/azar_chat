import 'dart:math';

import 'package:flutter/material.dart';

import '../../kc/atoms.dart';
import '../../kc/tokens.dart';
import '../game_controller.dart';
import '../games_data.dart';

/// Adam Asmaca — host picks a word from the bank, peer guesses.
/// Wrong guesses up to 7 → guesser loses.
class HangmanGame extends StatefulWidget {
  const HangmanGame({super.key});
  @override
  State<HangmanGame> createState() => _HangmanGameState();
}

class _HangmanGameState extends State<HangmanGame> {
  final _gc = GameController.instance;
  static const _alphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

  @override
  void initState() {
    super.initState();
    _gc.addListener(_onChange);
    _gc.onPeerMove = _applyPeerMove;

    // If I'm host, pick a word on first build.
    if (_gc.state['myRole'] == 'setter' && (_gc.state['word'] as String).isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickWord());
    }
  }

  @override
  void dispose() {
    _gc.removeListener(_onChange);
    _gc.onPeerMove = null;
    super.dispose();
  }

  void _onChange() { if (mounted) setState(() {}); }

  void _pickWord() {
    final rnd = Random(DateTime.now().microsecondsSinceEpoch);
    final word = kHangmanWords[rnd.nextInt(kHangmanWords.length)].toLowerCase();
    final masked = word.split('').map((c) => c == ' ' ? ' ' : '_').join(' ');
    final fresh = {
      ..._gc.state,
      'word': word,
      'masked': masked,
      'tried': <String>[],
      'wrong': 0,
      'turn': 'guesser',
      'winner': '',
    };
    _gc.applyState(fresh);
    // Broadcast only the masked + reset, NOT the word (peer must guess).
    _gc.broadcastState({
      ..._gc.state,
      'word': '',
      'masked': masked,
      'tried': <String>[],
      'wrong': 0,
      'turn': 'guesser',
      'winner': '',
    });
  }

  void _guess(String letter) {
    final s = _gc.state;
    if (s['myRole'] != 'guesser') return;
    if ((s['winner'] as String).isNotEmpty) return;
    final tried = List<String>.from(s['tried'] as List);
    if (tried.contains(letter)) return;
    tried.add(letter);
    // Local guesser doesn't know the word; just send the move. Setter updates state.
    _gc.sendMove({'letter': letter, 'tried': tried});
    _gc.applyState({...s, 'tried': tried});
  }

  void _applyPeerMove(Map<String, dynamic> data) {
    final s = _gc.state;
    if (s['myRole'] == 'setter') {
      // Peer (guesser) sent a letter; I know the word, compute the new state + broadcast.
      final letter = data['letter'] as String?;
      if (letter == null) return;
      final word = s['word'] as String;
      final tried = List<String>.from(data['tried'] as List);

      final maskedChars = word.split('').map((c) {
        if (c == ' ') return ' ';
        return tried.contains(c) ? c : '_';
      }).toList();
      final maskedDisplay = maskedChars.join(' ');
      final wrong = (s['wrong'] as int) + (word.contains(letter) ? 0 : 1);

      String winner = '';
      if (!maskedDisplay.contains('_')) {
        winner = 'guesser';
      } else if (wrong >= 7) {
        winner = 'setter';
      }

      final fresh = {
        ...s,
        'tried': tried,
        'wrong': wrong,
        'masked': maskedDisplay,
        'winner': winner,
      };
      _gc.applyState(fresh);

      // Broadcast peer view: hide actual word until game ends, then reveal.
      _gc.broadcastState({
        ...fresh,
        'word': winner.isEmpty ? '' : word,
      });
    } else {
      // Guesser side will be updated via 'state' broadcasts from setter.
    }
  }

  void _newRound() {
    if (_gc.state['myRole'] != 'setter') return;
    _pickWord();
  }

  @override
  Widget build(BuildContext context) {
    final s = _gc.state;
    final masked = s['masked'] as String? ?? '';
    final tried = (s['tried'] as List).cast<String>();
    final wrong = s['wrong'] as int? ?? 0;
    final winner = s['winner'] as String? ?? '';
    final role = s['myRole'] as String? ?? 'guesser';

    final String banner;
    if (winner == 'guesser') {
      banner = role == 'guesser' ? '🎉 Buldun!' : 'Rakip bildi';
    } else if (winner == 'setter') {
      banner = role == 'setter' ? '🪢 Asıldı, kazandın' : 'Asıldın — kelime: ${s['word']}';
    } else if (masked.isEmpty) {
      banner = role == 'setter' ? 'Kelime seçiliyor...' : 'Karşı taraf kelime seçiyor...';
    } else {
      banner = role == 'guesser' ? 'Tahmin et • Yanlış: $wrong/7' : 'Karşı tahmin ediyor • Yanlış: $wrong/7';
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      _Gallows(wrong: wrong),
      const SizedBox(height: 8),
      Text(banner, style: kcSora(13, w: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 10),
      Text(masked, style: const TextStyle(color: Colors.white, fontSize: 22,
        fontWeight: FontWeight.w800, letterSpacing: 3)),
      const SizedBox(height: 14),
      if (role == 'guesser' && winner.isEmpty && masked.isNotEmpty)
        Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.center, children: [
          for (final l in _alphabet.split(''))
            _LetterBtn(letter: l, used: tried.contains(l), onTap: () => _guess(l)),
        ]),
      if (winner.isNotEmpty) ...[
        const SizedBox(height: 12),
        if (role == 'setter') GestureDetector(
          onTap: _newRound,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(gradient: KC.grad,
              borderRadius: BorderRadius.all(Radius.circular(12))),
            child: Text('Yeni kelime',
              style: kcSora(13.5, w: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    ]);
  }
}

class _LetterBtn extends StatelessWidget {
  const _LetterBtn({required this.letter, required this.used, required this.onTap});
  final String letter;
  final bool used;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: used ? null : onTap,
      child: Container(
        width: 28, height: 32,
        decoration: BoxDecoration(
          color: used ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: used ? 0.06 : 0.22)),
        ),
        alignment: Alignment.center,
        child: Text(letter.toUpperCase(), style: TextStyle(
          color: used ? Colors.white24 : Colors.white,
          fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}

class _Gallows extends StatelessWidget {
  const _Gallows({required this.wrong});
  final int wrong;
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 110, height: 110,
      child: CustomPaint(painter: _GallowsPainter(wrong: wrong)));
  }
}

class _GallowsPainter extends CustomPainter {
  _GallowsPainter({required this.wrong});
  final int wrong;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // base
    if (wrong >= 1) canvas.drawLine(const Offset(10, 100), const Offset(80, 100), p);
    // pole
    if (wrong >= 2) canvas.drawLine(const Offset(25, 100), const Offset(25, 12), p);
    // beam
    if (wrong >= 3) canvas.drawLine(const Offset(25, 12), const Offset(70, 12), p);
    // rope
    if (wrong >= 4) canvas.drawLine(const Offset(70, 12), const Offset(70, 28), p);
    // head
    if (wrong >= 5) canvas.drawCircle(const Offset(70, 38), 9, p);
    // body
    if (wrong >= 6) canvas.drawLine(const Offset(70, 47), const Offset(70, 75), p);
    // arms + legs
    if (wrong >= 7) {
      canvas.drawLine(const Offset(70, 55), const Offset(60, 65), p);
      canvas.drawLine(const Offset(70, 55), const Offset(80, 65), p);
      canvas.drawLine(const Offset(70, 75), const Offset(60, 88), p);
      canvas.drawLine(const Offset(70, 75), const Offset(80, 88), p);
    }
  }
  @override
  bool shouldRepaint(_GallowsPainter old) => old.wrong != wrong;
}
