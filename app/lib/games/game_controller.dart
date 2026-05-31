import 'package:flutter/foundation.dart';

import '../state/app_controller.dart';

/// Wire protocol (over WebRTC data channel, type='g'):
///
///   {kind: 'invite',  game: 'xox'|'hangman'|'truth_dare', from: 'me'}
///   {kind: 'accept',  game: ...}
///   {kind: 'decline'}
///   {kind: 'move',    game: ..., data: {...}}
///   {kind: 'state',   game: ..., data: {...}}   // server-of-truth side broadcasts
///   {kind: 'end',     game: ..., reason: 'done'|'quit'|'timeout'}
///
/// Only one game runs at a time per match. End on next/disconnect.
enum GameKind { xox, hangman, truthDare }

extension GameKindX on GameKind {
  String get wire => switch (this) {
    GameKind.xox        => 'xox',
    GameKind.hangman    => 'hangman',
    GameKind.truthDare  => 'truth_dare',
  };
  String get label => switch (this) {
    GameKind.xox        => 'XOX',
    GameKind.hangman    => 'Adam Asmaca',
    GameKind.truthDare  => 'Doğruluk mu Cesaret mi',
  };
  String get emoji => switch (this) {
    GameKind.xox        => '⭕',
    GameKind.hangman    => '🪢',
    GameKind.truthDare  => '🎭',
  };
}

GameKind? gameKindFromWire(String? s) {
  switch (s) {
    case 'xox':        return GameKind.xox;
    case 'hangman':    return GameKind.hangman;
    case 'truth_dare': return GameKind.truthDare;
    default:           return null;
  }
}

enum GameStatus { idle, inviteSent, inviteReceived, playing }

/// Singleton — bound to the in-call AppController by KCContext.
class GameController extends ChangeNotifier {
  GameController._();
  static final GameController instance = GameController._();

  AppController? _app;

  GameStatus status = GameStatus.idle;
  GameKind? activeGame;     // current invite / running game
  Map<String, dynamic> state = const {};  // game-specific state map
  bool isHost = false;      // whichever side sent the invite

  void bind(AppController app) {
    if (_app == app) return;
    _app = app;
    app.onGamePayload = _onPeer;
  }

  void resetAll() {
    status = GameStatus.idle;
    activeGame = null;
    state = const {};
    isHost = false;
    notifyListeners();
  }

  // ── invite flow ──────────────────────────────────────────────────────

  void invite(GameKind kind) {
    if (status != GameStatus.idle && status != GameStatus.inviteReceived) return;
    activeGame = kind;
    status = GameStatus.inviteSent;
    isHost = true;
    _app?.sendGame({'kind': 'invite', 'game': kind.wire});
    notifyListeners();
  }

  void acceptInvite() {
    if (status != GameStatus.inviteReceived || activeGame == null) return;
    status = GameStatus.playing;
    state = _initialState(activeGame!, hostStarts: false /* peer is host */);
    _app?.sendGame({'kind': 'accept', 'game': activeGame!.wire});
    notifyListeners();
  }

  void declineInvite() {
    _app?.sendGame({'kind': 'decline'});
    resetAll();
  }

  void quit() {
    if (status == GameStatus.idle) return;
    _app?.sendGame({'kind': 'end', 'reason': 'quit'});
    resetAll();
  }

  // ── moves ────────────────────────────────────────────────────────────

  /// Both sides hold the same state; whoever moves applies locally then
  /// broadcasts the move. A 'state' broadcast is reserved for host-side
  /// authoritative resets (e.g. new round, RNG-driven cards).
  void sendMove(Map<String, dynamic> data) {
    if (status != GameStatus.playing || activeGame == null) return;
    _app?.sendGame({'kind': 'move', 'game': activeGame!.wire, 'data': data});
  }

  void broadcastState(Map<String, dynamic> data) {
    if (status != GameStatus.playing || activeGame == null) return;
    _app?.sendGame({'kind': 'state', 'game': activeGame!.wire, 'data': data});
  }

  /// Apply a state mutation (after sendMove on local side, or after
  /// receiving 'move'/'state' from peer). UI rebuilds via notifyListeners.
  void applyState(Map<String, dynamic> newState) {
    state = newState;
    notifyListeners();
  }

  // ── peer events ──────────────────────────────────────────────────────

  /// Caller (typically the game widget) wires this to react to peer moves
  /// without re-rendering the whole tree.
  void Function(Map<String, dynamic> moveData)? onPeerMove;

  void _onPeer(Map<String, dynamic> p) {
    final kind = p['kind'] as String?;
    switch (kind) {
      case 'invite':
        final k = gameKindFromWire(p['game'] as String?);
        if (k == null) return;
        activeGame = k;
        status = GameStatus.inviteReceived;
        isHost = false;
        notifyListeners();
        return;
      case 'accept':
        if (status != GameStatus.inviteSent) return;
        status = GameStatus.playing;
        state = _initialState(activeGame!, hostStarts: true);
        notifyListeners();
        return;
      case 'decline':
        resetAll();
        return;
      case 'end':
        resetAll();
        return;
      case 'move':
        onPeerMove?.call((p['data'] as Map).cast<String, dynamic>());
        return;
      case 'state':
        applyState((p['data'] as Map).cast<String, dynamic>());
        return;
    }
  }

  Map<String, dynamic> _initialState(GameKind k, {required bool hostStarts}) {
    switch (k) {
      case GameKind.xox:
        // 9 cells, '' empty. Host plays 'X', peer plays 'O'.
        // hostStarts == true → host's turn, else peer's turn.
        return {
          'cells': List.filled(9, ''),
          'myMark': isHost ? 'X' : 'O',
          'turn': hostStarts ? 'X' : 'O',
          'winner': '',  // '', 'X', 'O', or 'draw'
        };
      case GameKind.hangman:
        // Host picks word; sent via first move with full word visible only locally.
        // Until host sends a word, state.word == '' and peer just waits.
        return {
          'word': '',           // host-side full word (lowercase TR)
          'masked': '',         // peer-visible masked '_ _ _ _'
          'tried': <String>[],  // letters guessed (all)
          'wrong': 0,           // wrong-guess count, max 7
          'myRole': isHost ? 'setter' : 'guesser',
          'turn': 'guesser',    // setter only acts on initial word-pick
          'winner': '',         // '', 'guesser', 'setter'
        };
      case GameKind.truthDare:
        // Spinner-style. Host advances rounds. data['picked'] = 'truth' | 'dare' | null.
        return {
          'myTurn': hostStarts,  // true → I pick; false → peer picks
          'picked': '',          // '' | 'truth' | 'dare'
          'card':   '',          // current card text
          'round':  0,
        };
    }
  }
}
