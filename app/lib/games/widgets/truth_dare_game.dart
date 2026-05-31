import 'dart:math';

import 'package:flutter/material.dart';

import '../../kc/atoms.dart';
import '../../kc/tokens.dart';
import '../game_controller.dart';
import '../games_data.dart';

/// Doğruluk mu cesaret mi — whoever's turn picks truth or dare,
/// a random card is drawn (host-side RNG, broadcast to peer).
class TruthDareGame extends StatefulWidget {
  const TruthDareGame({super.key});
  @override
  State<TruthDareGame> createState() => _TruthDareGameState();
}

class _TruthDareGameState extends State<TruthDareGame> {
  final _gc = GameController.instance;

  @override
  void initState() {
    super.initState();
    _gc.addListener(_onChange);
    _gc.onPeerMove = _applyPeerMove;
  }

  @override
  void dispose() {
    _gc.removeListener(_onChange);
    _gc.onPeerMove = null;
    super.dispose();
  }

  void _onChange() { if (mounted) setState(() {}); }

  void _pick(String type) {
    final s = _gc.state;
    if (!(s['myTurn'] as bool)) return;
    if ((s['picked'] as String).isNotEmpty) return;
    final rnd = Random(DateTime.now().microsecondsSinceEpoch);
    final pool = type == 'truth' ? kTruthCards : kDareCards;
    final card = pool[rnd.nextInt(pool.length)];
    final fresh = {...s, 'picked': type, 'card': card};
    _gc.applyState(fresh);
    _gc.broadcastState(fresh);
  }

  void _next() {
    final s = _gc.state;
    final fresh = {
      ...s,
      'myTurn': !(s['myTurn'] as bool),
      'picked': '',
      'card': '',
      'round': (s['round'] as int) + 1,
    };
    // Both sides flip myTurn — but flipping locally inverts ownership;
    // broadcast inverse so peer also flips correctly.
    _gc.applyState(fresh);
    _gc.broadcastState({...fresh, 'myTurn': s['myTurn'] as bool});
  }

  void _applyPeerMove(Map<String, dynamic> data) {
    // Truth/dare uses 'state' broadcasts only; moves not used.
  }

  @override
  Widget build(BuildContext context) {
    final s = _gc.state;
    final myTurn = s['myTurn'] as bool;
    final picked = s['picked'] as String;
    final card = s['card'] as String;
    final round = s['round'] as int;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Tur ${round + 1}',
        style: kcManrope(11, w: FontWeight.w700, color: Colors.white60, letter: 1.6)),
      const SizedBox(height: 6),
      Text(myTurn ? 'Sıra sende' : 'Sıra rakipte',
        style: kcSora(16, w: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 16),

      if (picked.isEmpty && myTurn) Row(mainAxisSize: MainAxisSize.min, children: [
        _bigBtn('Doğruluk', '🤔', const Color(0xFF6BC4FF), () => _pick('truth')),
        const SizedBox(width: 14),
        _bigBtn('Cesaret', '🔥', const Color(0xFFFF6B9D), () => _pick('dare')),
      ]),

      if (picked.isEmpty && !myTurn)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14)),
          child: Text('Rakip seçim yapıyor...',
            style: kcManrope(13, color: Colors.white70))),

      if (picked.isNotEmpty) Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (picked == 'truth' ? const Color(0xFF6BC4FF) : const Color(0xFFFF6B9D))
              .withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999)),
          child: Text(picked == 'truth' ? '🤔 DOĞRULUK' : '🔥 CESARET',
            style: kcSora(11.5, w: FontWeight.w800, color: Colors.white, letter: 1.2)),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxWidth: 320, minHeight: 90),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Colors.white.withValues(alpha: 0.13), Colors.white.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
          child: Text(card, textAlign: TextAlign.center,
            style: kcSora(15.5, w: FontWeight.w600, color: Colors.white, height: 1.45)),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _next,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: const BoxDecoration(gradient: KC.grad,
              borderRadius: BorderRadius.all(Radius.circular(12))),
            child: Text('Sıradaki tur',
              style: kcSora(13.5, w: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
    ]);
  }

  Widget _bigBtn(String label, String emoji, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110, height: 110,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 6),
          Text(label, style: kcSora(13, w: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }
}
