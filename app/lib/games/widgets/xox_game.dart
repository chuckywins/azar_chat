import 'package:flutter/material.dart';

import '../../kc/atoms.dart';
import '../../kc/tokens.dart';
import '../game_controller.dart';
import '../games_data.dart';

/// XOX board — both sides see the same 9-cell grid.
/// Local plays whatever myMark is; on tap we mutate state + sendMove.
class XoxGame extends StatefulWidget {
  const XoxGame({super.key});
  @override
  State<XoxGame> createState() => _XoxGameState();
}

class _XoxGameState extends State<XoxGame> {
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

  String _winnerCheck(List<String> cells) {
    for (final line in kXoxWinLines) {
      final a = cells[line[0]], b = cells[line[1]], c = cells[line[2]];
      if (a.isNotEmpty && a == b && b == c) return a;
    }
    if (cells.every((c) => c.isNotEmpty)) return 'draw';
    return '';
  }

  void _tap(int i) {
    final s = _gc.state;
    final cells = List<String>.from(s['cells'] as List);
    if (cells[i].isNotEmpty) return;
    if ((s['winner'] as String).isNotEmpty) return;
    if (s['turn'] != s['myMark']) return;

    cells[i] = s['myMark'] as String;
    final winner = _winnerCheck(cells);
    final nextTurn = (s['myMark'] == 'X') ? 'O' : 'X';
    _gc.applyState({...s, 'cells': cells, 'turn': nextTurn, 'winner': winner});
    _gc.sendMove({'i': i});
  }

  void _applyPeerMove(Map<String, dynamic> data) {
    final i = data['i'] as int?;
    if (i == null) return;
    final s = _gc.state;
    final cells = List<String>.from(s['cells'] as List);
    if (cells[i].isNotEmpty) return;
    final peerMark = (s['myMark'] == 'X') ? 'O' : 'X';
    cells[i] = peerMark;
    final winner = _winnerCheck(cells);
    final nextTurn = (s['myMark'] as String);
    _gc.applyState({...s, 'cells': cells, 'turn': nextTurn, 'winner': winner});
  }

  void _newRound() {
    final s = _gc.state;
    final fresh = {
      ...s,
      'cells': List.filled(9, ''),
      'turn': 'X',
      'winner': '',
    };
    _gc.applyState(fresh);
    _gc.broadcastState(fresh);
  }

  @override
  Widget build(BuildContext context) {
    final s = _gc.state;
    final cells = (s['cells'] as List).cast<String>();
    final myMark = s['myMark'] as String;
    final turn = s['turn'] as String;
    final winner = s['winner'] as String;
    final myTurn = turn == myMark && winner.isEmpty;

    String topLabel;
    if (winner == 'draw') {
      topLabel = 'Berabere';
    } else if (winner == myMark) {
      topLabel = 'Kazandın! 🎉';
    } else if (winner.isNotEmpty) {
      topLabel = 'Kaybettin';
    } else {
      topLabel = myTurn ? 'Sıra sende ($myMark)' : 'Sıra rakipte';
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(topLabel, style: kcSora(15, w: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 14),
      AspectRatio(aspectRatio: 1,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemBuilder: (_, i) {
            final v = cells[i];
            return GestureDetector(
              onTap: () => _tap(i),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                alignment: Alignment.center,
                child: Text(v,
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800,
                    color: v == 'X' ? KC.accent : KC.accent2)),
              ),
            );
          },
        )),
      const SizedBox(height: 12),
      if (winner.isNotEmpty)
        GestureDetector(
          onTap: _newRound,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(gradient: KC.grad,
              borderRadius: BorderRadius.all(Radius.circular(12))),
            child: Text('Yeni tur',
              style: kcSora(13.5, w: FontWeight.w700, color: Colors.white)),
          ),
        ),
    ]);
  }
}
