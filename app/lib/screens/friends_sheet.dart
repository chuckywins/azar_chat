import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/friends_service.dart';
import '../theme.dart';

Future<void> showFriendsSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _FriendsSheet(),
  );
}

class _FriendsSheet extends StatefulWidget {
  const _FriendsSheet();

  @override
  State<_FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<_FriendsSheet> {
  late Future<List<FriendInfo>> _future = FriendsService.instance.myFriends();

  Future<void> _refresh() async {
    setState(() => _future = FriendsService.instance.myFriends());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.78;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        gradient: AzarPalette.surfaceGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AzarPalette.line)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AzarPalette.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AzarPalette.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.favorite_rounded, color: AzarPalette.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Text('Arkadaşların', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AzarPalette.textDim, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AzarPalette.line),
          Expanded(
            child: RefreshIndicator(
              color: AzarPalette.primary,
              onRefresh: _refresh,
              child: FutureBuilder<List<FriendInfo>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AzarPalette.primary, strokeWidth: 2.4));
                  }
                  if (snap.hasError) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('${snap.error}', style: const TextStyle(color: AzarPalette.danger)),
                    ));
                  }
                  final friends = snap.data ?? const [];
                  if (friends.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 60),
                        Center(
                          child: Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: AzarPalette.surfaceHigh,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.favorite_outline_rounded, color: AzarPalette.textDim, size: 28),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Henüz arkadaşın yok.\nGörüşme sırasında kalbe basarsan ve karşı taraf da basarsa burada görünür.',
                              style: TextStyle(color: AzarPalette.textDim, fontSize: 14, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    itemBuilder: (_, i) => _FriendTile(friend: friends[i])
                        .animate().fadeIn(duration: 280.ms, delay: (i * 30).ms).slideX(begin: -0.05),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: friends.length,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});
  final FriendInfo friend;

  @override
  Widget build(BuildContext context) {
    final nick = friend.nickname ?? 'Misafir';
    final initial = nick.isNotEmpty ? nick.substring(0, 1).toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AzarPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AzarPalette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: AzarPalette.brandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nick, style: const TextStyle(color: AzarPalette.text, fontSize: 14.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.shield_rounded,
                        color: _trustColor(friend.trustScore), size: 12),
                    const SizedBox(width: 4),
                    Text('Güven ${friend.trustScore ?? '-'}',
                        style: const TextStyle(color: AzarPalette.textFaint, fontSize: 11)),
                    if (friend.becameAt != null) ...[
                      const SizedBox(width: 8),
                      Text('• ${_relative(friend.becameAt!)}',
                          style: const TextStyle(color: AzarPalette.textFaint, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _trustColor(int? s) {
    if (s == null) return AzarPalette.textFaint;
    if (s >= 75) return AzarPalette.success;
    if (s >= 50) return AzarPalette.secondary;
    if (s >= 25) return AzarPalette.warning;
    return AzarPalette.danger;
  }

  String _relative(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'az önce';
    if (d.inMinutes < 60) return '${d.inMinutes}dk önce';
    if (d.inHours < 24) return '${d.inHours}sa önce';
    return '${d.inDays}g önce';
  }
}
